#############################################
# Locals for naming + standard tagging
#############################################
locals {
  # Constructs a consistent and unique name using project and environment variables.
  name = "${var.project_name}-${var.environment}-render-base"

  # Standard tags applied to all related AWS resources for identification and organization.
  tags = {
    Project     = var.project_name
    Environment = var.environment
    Role        = "stack-ssm" # Identifies this resource's purpose.
  }
}

#############################################
# PostgreSQL password management (host-level)
#############################################
# Generates a strong, random password for PostgreSQL if one isn't provided.
resource "random_password" "pg" {
  length  = 24
  special = false
  # The 'keepers' block ensures the password is regenerated ONLY if `var.postgres_password` is empty.
  keepers = { k = var.postgres_password == "" ? "gen" : "fixed" }
}

# Stores the effective PostgreSQL password (either provided or generated) securely in AWS SSM Parameter Store.
resource "aws_ssm_parameter" "pg_password" {
  # Defines the full path for easy retrieval in the format: /projects/PROJECT/ENVIRONMENT/stack/pg_password.
  name = "/projects/${var.project_name}/${var.environment}/stack/pg_password"
  type = "SecureString" # Essential for encrypting sensitive data like passwords.
  # If a password is provided (not empty), use it; otherwise, use the random one.
  value       = var.postgres_password != "" ? var.postgres_password : random_password.pg.result
  description = "Docker Postgres password for local container"
  tags        = local.tags
}

#############################################
# Docker Compose variants (Postgres 17)
#############################################
locals {
  # Defines the Docker Compose YAML content for a stack containing only a PostgreSQL container.
  compose_base = <<-YML
    services:
      postgres:
        image: postgres:17-alpine
        container_name: pg
        restart: unless-stopped
        environment:
          POSTGRES_USER: ${var.postgres_user}
          # Injects the secure password retrieved from the SSM Parameter.
          POSTGRES_PASSWORD: ${aws_ssm_parameter.pg_password.value}
          POSTGRES_DB: ${var.postgres_db}
        ports:
          - "${var.postgres_port}:5432"
        volumes:
          # Maps a host directory for persistent database storage.
          - ${var.stack_dir}/runtime/pgdata:/var/lib/postgresql/data
    volumes: {}
  YML

  # Defines the Docker Compose YAML content for a stack containing PostgreSQL AND an optional 'hello' web service.
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
          POSTGRES_PASSWORD: ${aws_ssm_parameter.pg_password.value}
          POSTGRES_DB: ${var.postgres_db}
        ports:
          - "${var.postgres_port}:5432"
        volumes:
          - ${var.stack_dir}/runtime/pgdata:/var/lib/postgresql/data
    volumes: {}
  YML

  # Selects the appropriate Docker Compose YAML based on the boolean variable `var.enable_hello_http`.
  compose_yaml = var.enable_hello_http ? local.compose_with_hello : local.compose_base
}

#############################################
# Official Docker Ubuntu install sequence
# (EXACT flow you provided, wrapped in a guard)
#############################################
locals {
  # Shell script lines to install Docker and Docker Compose on an Ubuntu instance, guarded by a check to prevent re-installing.
  docker_install_lines = [
    # Heredoc containing the multi-line shell script for Docker installation.
    <<-EOT
      if ! command -v docker >/dev/null 2>&1; then
        set -euo pipefail
        export DEBIAN_FRONTEND=noninteractive

        # Remove conflicting packages (ignore if absent)
        for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do
          sudo apt-get remove -y "$pkg" || true
        done

        # Add Docker's official GPG key:
        sudo apt-get update -y
        sudo apt-get install -y ca-certificates curl
        sudo install -m 0755 -d /etc/apt/keyrings
        sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
        sudo chmod a+r /etc/apt/keyrings/docker.asc

        # Add the repository to Apt sources:
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo \"$${UBUNTU_CODENAME:-$VERSION_CODENAME}\") stable" | \
          sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        sudo apt-get update -y

        # Install Docker Engine + plugins
        sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

        # Ensure daemon is enabled and running
        sudo systemctl enable --now docker
      fi
    EOT
  ]

  # Core script lines to set up directories, write the Compose file, and start the containers.
  base_lines = [
    "set -euo pipefail",                                                          # Exit immediately on error or undefined variable.
    "STACK_DIR='${var.stack_dir}'",                                               # Defines the base directory for the stack on the instance.
    "mkdir -p \"$STACK_DIR/compose\" \"$STACK_DIR/runtime\" \"$STACK_DIR/logs\"", # Create required directories.

    # Write our compose YAML to a file on the instance.
    "cat > \"$STACK_DIR/compose/docker-compose.yml\" <<'COMPOSE'",
    local.compose_yaml,
    "COMPOSE",

    # Bring up the Docker stack in detached mode (-d).
    "docker compose -f \"$STACK_DIR/compose/docker-compose.yml\" up -d",

    # Confirmation commands to check Docker/Compose versions and running containers.
    "docker --version || true",
    "docker compose version || true",
    "docker ps --format 'table {{.Names}}\\t{{.Image}}\\t{{.Status}}\\t{{.Ports}}'"
  ]

  # Concatenates the Docker install script (if enabled by the variable) and the base startup script.
  run_commands = concat(
    var.install_docker_if_missing ? local.docker_install_lines : [],
    local.base_lines
  )
}

#############################################
# SSM Document + Association (runs on instance)
#############################################
# Creates the AWS Systems Manager Document, which acts as a script container for remote execution.
resource "aws_ssm_document" "render_base" {
  # Sanitizes the name for AWS requirements (e.g., replaces underscores with hyphens).
  name          = replace(local.name, "_", "-")
  document_type = "Command" # Specifies that this document runs shell commands.
  tags          = local.tags

  # The JSON content defining the shell script to run.
  content = jsonencode({
    schemaVersion = "2.2",
    description   = "Render base stack (compose) and start containers",
    mainSteps = [
      {
        action = "aws:runShellScript",
        name   = "RenderAndStart",
        inputs = { runCommand = local.run_commands } # Passes the final list of shell commands.
      }
    ]
  })
}

# Creates the AWS SSM Association, which immediately executes the Document on the specified EC2 instance(s).
resource "aws_ssm_association" "render_base" {
  name = aws_ssm_document.render_base.name
  targets {
    key    = "InstanceIds"
    values = [var.instance_id] # Targets the single EC2 instance defined by the input variable.
  }
}
