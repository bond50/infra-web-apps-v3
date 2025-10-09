# Infra Roadmap & Step‑by‑Step Rollout (Terraform + GitHub Actions)

**Project:** infra‑web‑apps‑v3  
**Goal:** Ship a cost‑aware AWS base that can host **multiple apps** on **one EC2** (Docker/Compose, Caddy SSL, optional premium certs), with **Postgres mandatory** (either on the same box via Docker, or later split out), **SSM automation**, **S3 backups**, and a **CI‑first flow** (plan on branches, apply on `main`).

This guide is the **single source of truth** for how we roll out features—one at a time—using pull requests and GitHub Actions.

---

## 0) What’s already in the repo (baseline)

- **Git flow** and branch protections (squash‑only).
- **Workflows**
  - `05 - PR Quality Gate` → fmt, validate, tflint, checkov, plan (PRs).
  - `10 - Terraform` → plan on branches/PRs, **apply only on push to `main`** (gated by Environment `production`).
  - `90 - Terraform Destroy (manual)` → typed confirmation + environment approval.
  - `00 - Bootstrap AWS Backend` → one‑time: S3 state, DynamoDB lock, OIDC Role, repo variables.
- **Backend**: S3 (encrypted + versioned) + DynamoDB lock.
- **Modules (local)** you’ll see:
  - `modules/network` → wraps terraform‑aws‑modules/vpc to make a VPC with public/private‑app/private‑db subnets and **free S3/DynamoDB Gateway endpoints**.
  - `modules/compute_app_host` → EC2 (default `t4g.small`), SG (80/443 + SSH as configured), optional EIP, user‑data (Docker + Caddy + placeholders for Compose).
  - `modules/stack-ssm` → SSM Document + Associations for: Docker/Caddy bootstrap, mandatory **Postgres (Docker)**, and **nightly pg_dump to S3**.

> **Postgres is mandatory**. By default we use **Dockerized Postgres on the EC2 instance**. Later we can flip to “external DB” (e.g., RDS or another EC2) behind a variable flag without rewriting the stack.

---

## 1) Secrets & Variables (foundation)

All CI runs assume these **GitHub → Settings → Secrets and variables** entries exist.

### Repository Variables (non‑secret)
- `AWS_REGION` → e.g., `us-east-1`
- `AWS_ROLE_ARN` → the OIDC role ARN created by bootstrap
- `TF_STATE_BUCKET` → S3 bucket for Terraform state
- `TF_STATE_TABLE` → DynamoDB table (lock)
- `TF_STATE_KEY` → state key prefix (e.g., `infra/terraform.tfstate`)

### Repository Secrets (secret)
- (Only needed for **00‑Bootstrap**) `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `GH_ADMIN_TOKEN`.
- **App/Infra** (optional/when ready): `RESEND_API_KEY`, `SLACK_WEBHOOK_URL`, etc.
- **Cloudflare** (when DNS step starts): `CLOUDFLARE_API_TOKEN`.

> Tip: you can set these with the GitHub CLI:
> ```bash
> gh variable set AWS_REGION -b "us-east-1"
> gh variable set TF_STATE_BUCKET -b "my-tfstate-bucket"
> gh secret set RESEND_API_KEY -b "..." 
> ```

---

## 2) How we ship changes (CI‑first)

- **Branches/PRs**: you develop on feature branches. The PR automatically runs **PR Quality Gate** and a **Terraform plan**.
- **Apply**: only happens **after the PR is merged into `main`**. On push to `main`, the `10 - Terraform` job runs **apply** (gated by Env `production`).
- **Destroy**: use `90 - Terraform Destroy (manual)` with the confirmation phrase for safe teardowns (non‑prod only).

> **Local usage**: You can `terraform fmt/validate` locally to check syntax, but the source of truth for plan/apply is **GitHub Actions**.

---

## 3) Rollout Plan (one feature at a time)

We’ll enable features **in order**. Keep the root `main.tf` organized with **commented blocks**. Each step instructs what to **uncomment**, how to **test**, and what to **look for** in the AWS console.

### Phase A — VPC & Subnets (cheap by default)
1) **Uncomment only the** `module "network"` **block** in `main.tf`. Keep **all other modules commented**.
2) Commit → push → open PR → ensure the plan shows: VPC + 2 public subnets + 2 private‑app + 2 private‑db; **no NAT** by default (cost saver). It also creates **S3/DynamoDB Gateway Endpoints** for free egress in private subnets.
3) Merge PR → Actions will **apply** on `main`.
4) **Verify** in AWS Console:
   - VPC (CIDR you provided).
   - Subnets (public/private‑app/private‑db) across two AZs.
   - Route tables with default routes only in public subnets; no NAT until enabled.

> **Toggle NAT later** by flipping `enable_nat_gateway = true` (one shared NAT per VPC).

### Phase B — Compute Host (EC2 + SG + optional EIP)
1) **Uncomment** `module "compute_app_host"` in `main.tf`. Ensure:
   - `subnet_id = module.network.public_subnet_ids[0]`
   - `ssh_allowed_cidr` points to your IP (or VPN).
   - `use_eip` set as desired. If `true`, an EIP + association will be created.
2) PR → plan → merge → apply.
3) **Verify**: EC2 instance (Ubuntu 24), SG allows 80/443 (+ optional SSH). If EIP enabled, confirm the address.

### Phase C — SSM Bootstrap + Postgres (Docker) + Caddy
1) **Uncomment** `module "stack_ssm"` in `main.tf`. Keep `enable_local_postgres = true`* in compute module.  
   *This ensures the SSM document will install Docker, launch **Caddy** + **Postgres** containers and seed volumes under `stack_dir` (default `/opt/webstack`).*
2) PR → plan → merge → apply.
3) **Verify**:
   - **SSM > Managed Instances** shows the EC2.
   - **AWS Systems Manager → Automation/Run Command/State Manager**: the association(s) ran successfully.
   - On the instance: `docker ps` shows Caddy + Postgres.

> **SSL options**: by default Caddy will obtain Let’s Encrypt for configured domains. Later, for premium certificates, we’ll add a variable `ssl_mode = "premium"|"caddy"` and a place to upload cert/key via SSM Parameter or artifact; Caddy will be configured accordingly.

### Phase D — Nightly DB Backups to S3
1) Ensure a bucket is decided for dumps (we can reuse the tfstate bucket with a **separate prefix** or create a new bucket). Expose it via a variable `db_backup_bucket_name` (empty → auto‑name).
2) The SSM association schedules `pg_dump` at **02:00 UTC** nightly to S3.  
3) **Verify**: check the S3 prefix after a night (or trigger the association manually from SSM > State Manager).

### Phase E — Multi‑App (ECR + per‑app env in SSM/GitHub)
1) Add **ECR repositories** using a tiny wrapper module that takes your `var.apps` map and creates one repo per app (we’ll add `modules/ecr-multi`).  
2) Add **SSM Parameter Store** for `app_env_plain` + `app_env_secure` (mirroring your legacy pattern) so the SSM bootstrap can render per‑app `.env` files for Compose.
3) **DNS (Cloudflare)**: when ready, create `A/AAAA` records to the instance EIP (or CNAME to ALB if we later introduce it). We’ll manage Cloudflare via Terraform using the official provider once tokens are present.

---

## 4) Variables you’ll commonly touch

- **Project & region**: `project_name`, `environment`, `region`
- **Network**: `vpc_cidr`, `azs`, `public_subnet_cidrs`, `private_app_subnet_cidrs`, `private_db_subnet_cidrs`, `enable_nat_gateway`
- **Compute**: `instance_type` (default `t4g.small`), `root_volume_size`, `use_eip`, `ssh_allowed_cidr`, `ssh_port`, `open_ssh_22`
- **Stack**: `stack_dir` (default `/opt/webstack`), `caddy_email`
- **Postgres**: `postgres_user`, `postgres_password` (empty → auto‑generate), `postgres_default_db`
- **Backups**: `enable_pg_dump_to_s3` (default `true`), `db_backup_bucket_name`
- **Apps** (multi‑app): `apps` map, `app_env_plain`, `app_env_secure`

---

## 5) Comment/Uncomment recipe (exact)

In `main.tf` keep **only one** of the following active per phase:

```hcl
# Phase A (only this)
module "network" { ... }

# Phase B (network + compute)
module "network" { ... }
module "compute_app_host" { ... }

# Phase C (network + compute + ssm)
module "network" { ... }
module "compute_app_host" { ... }
module "stack_ssm" { ... }
```

If you prefer **feature flags** instead of comments, we can switch to:
```hcl
module "network"          { count = var.enable_network ? 1 : 0  ... }
module "compute_app_host" { count = var.enable_compute ? 1 : 0  ... }
module "stack_ssm"        { count = var.enable_stack_ssm ? 1 : 0 ... }
```
…and then reference outputs using index zero (e.g., `module.network[0].public_subnet_ids`), but comments are simpler to read right now.

---

## 6) Running the pipeline (PR → plan, main → apply)

1) **Branch**: `feature/aws-foundation` (or similar).
2) **Uncomment one phase**, commit, push.
3) **Open PR** to `develop`. Check `05 - PR Quality Gate` and the plan. Fix anything red.
4) **Merge to `develop`** (squash). Then **cut a release** (`release/*`) to ship to `main`, or if you allow direct PR dev→main for infra, open a PR to `main`.
5) On **push to `main`**, `10 - Terraform` applies (gated by environment). Approve the environment when prompted.
6) **Rollback**: Revert the merge commit; use `90 - Terraform Destroy` only for sandboxes.

---

## 7) Sanity checks (Console/CLI)

- VPC/Subnets/Routes visible, Gateway Endpoints present.
- EC2 up, SG ports 80/443 (+22 if enabled). EIP attached if requested.
- SSM → Managed instances shows the box online; associations show “Success”.
- On the instance: `docker ps` shows **caddy** and **postgres** containers.
- S3 → `db-backups/...` prefix filled after nightly run.

---

## 8) What’s next (queued features)

- **ECR multi‑repo** (`modules/ecr-multi`) driven by `var.apps`.
- **Per‑app Compose renderer** in SSM document (reads `app_env_*` from SSM and drops `.env` files).
- **Cloudflare DNS** module (A/AAAA or CNAME, proxied toggle).
- **Premium SSL**: `ssl_mode` variable; if `"premium"`, place cert/key chain via SSM Parameter (SecureString), and configure Caddy to use them; otherwise keep Let’s Encrypt.
- **Split Postgres**: `enable_local_postgres=false` and point apps to external DB (RDS or a second EC2); keep backup job targeting the right connection string.

---

## 9) FAQ

- **Why am I seeing “Backend initialization required” locally?**  
  Run `terraform init -reconfigure` once locally; in CI the backend is set automatically.
- **I only want to see a plan on my PR, not apply anything.**  
  That’s already the default. Apply runs only on push to `main`.
- **How do I test one piece without deploying others?**  
  Comment out the other module blocks in `main.tf` (see Phase recipe above).

---

**End of guide — keep this versioned in `docs/infra-roadmap.md`.**