# AWS Infra Roadmap — Multi‑App on One EC2 (Docker+Caddy+Postgres)  
**Version:** 2025-10-09 06:00 UTC • **Terraform:** 1.13.3 • **AWS Provider:** ~> 6.x • **Ubuntu:** 24.04

This is a **step‑by‑step** guide. We **implement one feature at a time, test, then proceed**.  
It matches your repo layout and Git flow (`main`, `develop`, `feature/*`, `release/*`, `hotfix/*`).

---

## Phase 0 — Foundations (once)
**Goal:** Backend, OIDC, branch rules, CI jobs, and required repo variables.

### 0.1 Repo Variables & Secrets (GitHub → Settings → Secrets and Variables → Actions)
**Variables (non‑secret):**
- `AWS_REGION` = e.g. `us-east-1`
- `AWS_ROLE_ARN` = from bootstrap output
- `TF_STATE_BUCKET` = from bootstrap output
- `TF_STATE_KEY` = state prefix (e.g. `infra/terraform.tfstate`)
- `TF_STATE_TABLE` = DynamoDB lock table (if used anywhere else)

**Secrets (as needed later):**
- `CLOUDFLARE_API_TOKEN` (if we manage DNS)
- `RESEND_API_KEY` and `SLACK_WEBHOOK_URL` (optional notifications)
- Any app secrets not stored via SSM yet

> You already have **05 - PR Quality Gate**, **10 - Terraform**, **90 - Destroy**, **99 - Rulesets**. Keep them as‑is.

### 0.2 Local CLI sanity
```bash
terraform -v          # must be 1.13.3
aws --version         # AWS CLI v2 recommended
gh --version          # GitHub CLI
```

---

## Phase 1 — Network (VPC + Subnets + Free Endpoints)
**Goal:** Create a low‑cost VPC with 2 AZs, 2 public + 2 private‑app + 2 private‑db subnets, **no NAT** by default, and **Gateway Endpoints** for S3/DynamoDB.

### What you already have
- `modules/network` that wraps `terraform-aws-modules/vpc/aws (~> 6.4)`
- Free **Gateway Endpoints** (S3 & DynamoDB) attached to private + db route tables

### Run & Test
```bash
# from the repo root (feature branch):
terraform init -reconfigure
terraform plan -out=tfplan.net
terraform apply tfplan.net

# outputs to check (example):
terraform output -json | jq '.network_*? // empty'
```

**Validation:**
- In AWS Console → VPC → Subnets: see 6 subnets with tags `Tier=public|private-app|private-db`
- VPC endpoints: `com.amazonaws.<region>.s3` and `...dynamodb` of type **Gateway**

---

## Phase 2 — Compute Host (EC2 for Apps)
**Goal:** One inexpensive EC2 (default `t4g.small`, Graviton) in a **public subnet**, security group for 80/443 (+optional SSH), optional **EIP**.

### Inputs to set at root (already present)
- `instance_type` (default `t4g.small`)
- `use_eip` (default `false`)
- `root_volume_size`, `stack_dir`

### Run & Test
```bash
terraform plan -out=tfplan.ec2
terraform apply tfplan.ec2
terraform output web_public_ip    # should show EC2 public/EIP
```

**Validation:**
- EC2 Console → instance is **running**
- Security Group allows **80/443** (and **22** only from your `ssh_allowed_cidr` if enabled)
- If `use_eip=true`, EIP is attached

---

## Phase 3 — SSM Base + Docker Runtime
**Goal:** Make the EC2 manageable via **SSM** and ensure **Docker** is installed & enabled.

What happens:
- SSM documents/associations ensure Docker is installed/started on Ubuntu 24.04
- We keep using **SSM Session Manager** (no SSH keys needed)

**Quick test:**
```bash
aws ssm start-session --target $(terraform output -raw web_instance_id)
# inside the shell
docker version
exit
```

---

## Phase 4 — Postgres on Host (Docker) — Mandatory
**Goal:** Always have **Postgres** available. For now we run it as a container on the same EC2.

Inputs:
- `postgres_user`, `postgres_password` (optional; auto‑gen later), `postgres_default_db`
- Toggle **future** split: `enable_external_postgres` (will default to `false`)

**Validation:**
```bash
aws ssm start-session --target $(terraform output -raw web_instance_id)
pg_isready -h 127.0.0.1 -p 5432 || docker exec -it postgres pg_isready
exit
```

---

## Phase 5 — Multi‑App on One Host (Compose + Caddy)
**Goal:** Multiple apps run as separate containers on the **same EC2**, served by **Caddy**.

### Inputs to add at root
```hcl
variable "apps" {{
  description = "Apps sharing the host"
  type = map(object({{ domain:string, zone:string, record_name:string, repo_name:string, github_repo:string, container_port:number }}))
}}

variable "app_env_plain"  {{ type = map(map(string)); default = {{}} }}
variable "app_env_secure" {{ type = map(map(string)); default = {{}} }}
variable "active_app"     {{ type = string; default = "" }} # '' => first app
```

### What the module will do (next step)
- Render **docker-compose.yml** with one service per app + shared `postgres` service
- Render **Caddyfile** with one vhost per app
  - **Premium SSL**: if SSM parameters `/{app}/ssl/cert`+`/{app}/ssl/key` exist, mount them
  - **Fallback SSL**: Caddy issues/renews via Let’s Encrypt using `caddy_email`

**Validation (after we add the module):**
```bash
aws ssm start-session --target $(terraform output -raw web_instance_id)
docker compose -f /opt/webstack/compose/docker-compose.yml ps
curl -I https://your-app-domain
exit
```

---

## Phase 6 — Backups (Nightly pg_dump to S3 + Manual Restore)
**Goal:** Nightly **pg_dump** the shared DB to **S3**, retain via S3 lifecycle; provide an **SSM restore** doc.

Inputs:
- `enable_pg_dump_to_s3` (default `true`)
- `db_backup_bucket_name` (optional, or auto‑name from project/env)

**Validation:**
- S3 bucket contains dated dumps under `postgres/backups/`
- Run restore SSM document in a sandbox to confirm

---

## Phase 7 — DNS (Cloudflare)
**Goal:** Optionally manage A/AAAA records for each app’s domain.

Inputs:
- `cloudflare_api_token` (secret)
- Per‑app: `domain`, `zone`, `record_name`, `cf_proxied`, `cf_ttl`

**Validation:**
- Cloudflare dashboard shows records
- `dig +short your-domain` resolves to your EIP/public IP

---

## Phase 8 — ECR + Deploy Hooks (per app)
**Goal:** Create an ECR repo per app + CI hooks to push images from each app repo.

What we add later:
- `modules/ecr-repository` (or registry module)
- GitHub Actions in each **app repo** to build/push to ECR (using OIDC)
- SSM “deploy” document to pull new tag & restart Compose service

**Validation:**
- `aws ecr describe-repositories`
- Pull/deploy works via SSM document

---

## Phase 9 — Destroy (safeguarded)
Use your existing **90 - Terraform Destroy (manual)** workflow. It requires a confirmation phrase and runs only on `main` under the protected environment.

---

## Project Structure (target)
```
.
├── backend.tf
├── providers.tf
├── data.tf
├── variables.tf
├── locals.tf
├── main.tf
├── outputs.tf
│
├── modules/
│   ├── network/               # VPC + subnets + endpoints
│   ├── compute_app_host/      # EC2 + SG + EIP + user_data
│   ├── stack-ssm/             # SSM docs/associations
│   ├── app-compose/           # (NEXT) render compose + Caddyfile from apps map
│   ├── db-backup/             # (NEXT) pg_dump to S3 + restore doc
│   ├── cloudflare-dns/        # (NEXT) optional DNS records per app
│   └── ecr-repository/        # (NEXT) ECR repos per app
│
├── docs/
│   ├── git-workflow-mastery.md / .html
│   └── infra-aws-roadmap.md / .html  ← YOU ARE HERE
│
├── .github/workflows/
│   ├── 05-pr-quality-gate.yml
│   ├── 10-terraform.yml
│   ├── 90-terraform-destroy.yml
│   └── 99-apply-github-rulesets.yml
└── README.md
```

---

## How we will ship each phase
Each phase will be delivered as **surgical patches** (open file → add/replace block), followed by **exact test steps** and **rollback notes**.

**Next up (Phase 5)**: introduce `apps` and produce the **Compose + Caddy** SSM render.  
We’ll commit, `terraform apply`, and then verify containers + TLS for one domain before we move on.