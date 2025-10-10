locals {
  name = "${var.project_name}-${var.environment}-compose-bootstrap"
  tags = {
    Project     = var.project_name
    Environment = var.environment
    Role        = "compose-bootstrap"
  }

  # SSM path to store host DB password
  pg_param_name = "/projects/${var.project_name}/${var.environment}/stack/pg_password"
}

resource "random_password" "pg" {
  length  = 24
  special = false
  keepers = { k = var.postgres_password == "" ? "gen" : "fixed" }
}

resource "aws_ssm_parameter" "pg_password" {
  name        = "/projects/${var.project_name}/${var.environment}/stack/pg_password"
  type        = "SecureString"
  value       = var.postgres_password != "" ? var.postgres_password : random_password.pg.result
  description = "Docker Postgres password for local container"
  overwrite   = true
  tags        = local.tags

  lifecycle {
    prevent_destroy = true
  }
}


# Compose YAML (Postgres 17 with optional hello)
locals {
  compose_base = <<-YML
    services:
      postgres:
        image: postgres:17-alpine
        container_name: pg
        restart: unless-stopped
        environment:
          POSTGRES_USER: ${var.postgres_user}
          POSTGRES_PASSWORD: "$${PG_PASSWORD}"
          POSTGRES_DB: ${var.postgres_db}
        ports:
          - "${var.postgres_port}:5432"
        volumes:
          - ${var.stack_dir}/runtime/pgdata:/var/lib/postgresql/data
    volumes: {}
  YML

  compose_with_hello = <<-YML
    services:
      hello:
        image: ${var.hello_image}
        container_name: hello
        restart: unless-stopped
        ports:
          - "${var.hello_port}:80"
      postgres:
        image: postgres:17-alpine
        container_name: pg
        restart: unless-stopped
        environment:
          POSTGRES_USER: ${var.postgres_user}
          POSTGRES_PASSWORD: "$${PG_PASSWORD}"
          POSTGRES_DB: ${var.postgres_db}
        ports:
          - "${var.postgres_port}:5432"
        volumes:
          - ${var.stack_dir}/runtime/pgdata:/var/lib/postgresql/data
    volumes: {}
  YML

  compose_yaml = var.enable_hello_http ? local.compose_with_hello : local.compose_base
}

# Cloud-init/user_data: installs Docker per official docs, fetches PG pwd from SSM, writes compose, up -d
locals {
  user_data = <<-UD
    #!/bin/bash
    set -euo pipefail
    export DEBIAN_FRONTEND=noninteractive

    # --- Docker install (Ubuntu official sequence) ---
    if ${var.install_docker_if_missing ? "true" : "false"}; then
      if ! command -v docker >/dev/null 2>&1; then
        # remove conflicting packages (ignore if absent)
        for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do
          apt-get remove -y "$pkg" || true
        done

        # Add Docker's official GPG key
        apt-get update -y
        apt-get install -y ca-certificates curl gnupg lsb-release awscli
        install -m 0755 -d /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
        chmod a+r /etc/apt/keyrings/docker.asc

        # Add the repository to Apt sources
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $${UBUNTU_CODENAME:-$VERSION_CODENAME} stable" \
          > /etc/apt/sources.list.d/docker.list
        apt-get update -y

        # Install Docker Engine + plugins
        apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

        systemctl enable --now docker
      fi
    fi

    # --- Folders ---
    STACK_DIR="${var.stack_dir}"
    mkdir -p "$STACK_DIR/compose" "$STACK_DIR/runtime" "$STACK_DIR/logs"

    # --- Fetch PG password from SSM (with decryption) ---
    PG_PARAM="${local.pg_param_name}"
    PG_PASSWORD="$(aws ssm get-parameter --name "$PG_PARAM" --with-decryption --query 'Parameter.Value' --output text)"

    # --- Write compose file ---
    cat > "$STACK_DIR/compose/docker-compose.yml" <<"COMPOSE"
    ${trimspace(local.compose_yaml)}
    COMPOSE

    # --- Bring up stack ---
    docker compose -f "$STACK_DIR/compose/docker-compose.yml" up -d

    # Health-ish logs
    docker --version || true
    docker compose version || true
    docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}' || true
  UD
}

output "user_data" {
  value = local.user_data
}
