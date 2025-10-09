# Infra Web Apps v3 — End‑to‑End Runbook (Git + Terraform + AWS)

> **Single source of truth for this repo.**  
> You can safely share this file with teammates. It merges: workflow rules, branch flow,
> CI pipelines, AWS stack layout, secrets/variables, and copy‑paste commands.

---

## 0) Golden rules (house style)
- **Squash‑only merges** on protected branches (`main`, `develop`).
- **Features → develop**, **Releases → main**, **Hotfixes → main**, then **sync main → develop**.
- **Change-only** in reviews: when asking for edits, we provide *patch-style* instructions (what file, where, add/replace). Full files only for brand‑new additions or when requested.
- **Terraform v1.13.3** everywhere; **AWS provider v6.x**; **Ubuntu 24.04** on EC2.
- **Modules-first** (prefer registry modules); **single entry point**: root `main.tf`.
- **Cost-aware defaults** (no NAT GW by default; gateway endpoints; small instance type).

---

## 1) Quick decision guide (branches)
- **New work (Features):** `feature/*` off `develop` → PR to `develop`.
- **Ship to Production:** `release/*` off `develop` → PR to `main` → **merge (squash)** → **APPLY**.
- **Emergency Fix:** `hotfix/*` off `main` → PR to `main` → **merge (squash)** → **APPLY** → back‑merge to `develop` (sync PR).

**Parity proof (content):**
```bash
git fetch origin --prune
git rev-parse origin/main^{tree}; git rev-parse origin/develop^{tree}
# if different:
git diff --name-status origin/main origin/develop
```

---

## 2) Pipelines (what runs, when)

### A) 05 - PR Quality Gate
- **Triggers:** PRs to any branch; also `merge_group`.
- **What it does:** `fmt` → `validate` → `tflint` → `checkov` → `plan` (no apply).
- **Required check name:** `05 - PR Quality Gate / pr-quality` (non‑strict).

**Recommended trigger block:**
```yaml
on:
  pull_request:
    branches: ["**"]
    types: [opened, synchronize, reopened]
  merge_group: {}
```

### B) 10 - Terraform (plan on branches, apply on main)
- **Triggers:** pushes on all branches and PRs.
- **Behavior:** plan on branches/PRs; **apply only on push to `main`**; gated by Environment `production` (reviewers).
- **Backend:** S3 (versioned, encrypted); OIDC to assume AWS role; 1 workspace per branch (`branch-<name>`).

### C) 90 - Terraform Destroy (manual, safeguarded)
- **Manual only.** Runs on `main` with environment approval. Requires typed confirm:
  `I UNDERSTAND THIS WILL DESTROY ALL RESOURCES`.
- Can run **plan-only** to inspect the destroy plan artifact first.

### D) 99 - Apply GitHub Rulesets (manual admin)
- Imports current repo & rulesets into Terraform state (prevents 422 errors), applies protections and **squash‑only** merge settings.

---

## 3) One‑time bootstrap (creates backend + OIDC + repo variables)
Run **“00 - Bootstrap AWS Backend”** in GitHub Actions with inputs:
- `bucket_name` (global unique), `dynamodb_table_name`, `tf_state_key`
- `github_owner`, `github_repo`, `project_name` (e.g., `web-apps`)

**Creates:** S3 (+versioning +SSE +TLS-only policy), DynamoDB (lock), OIDC provider, IAM role `${project_name}-gha`, and GitHub repo **Variables**.

Delete the temporary AWS access keys after success; OIDC takes over.

---

## 4) Secrets & Variables (GitHub → Settings → Secrets and variables → Actions)

### Variables (plain)
| Name | Example | Purpose |
|---|---|---|
| `AWS_REGION` | `us-east-1` | Deployment region |
| `AWS_ROLE_ARN` | `arn:aws:iam::123:role/web-apps-gha` | OIDC-assumable role |
| `TF_STATE_BUCKET` | `my-tfstate-123` | Remote state bucket |
| `TF_STATE_TABLE` | `tf-locks-my-tfstate` | Lock table (bootstrap) |
| `TF_STATE_KEY` | `infra/terraform.tfstate` | Base state key prefix |

### Secrets
| Name | Example | Notes |
|---|---|---|
| `GH_TOKEN_ADMIN` | `ghp_***` | Only for rulesets/admin import workflows |
| `CLOUDFLARE_API_TOKEN` | `***` | Manage DNS (if/when enabled) |
| `SLACK_WEBHOOK_URL` | `https://hooks.slack.com/...` | Optional notifications |
| `RESEND_API_KEY` | `re_*` | Optional email notifications |

> App‑specific env (per‑app) should go to SSM Parameter Store via module later; for now keep minimal in GitHub if needed.

---

## 5) Daily flow (features → releases → hotfixes → sync)

### Feature
```bash
git fetch origin --prune
git switch develop && git pull --rebase
git switch -c feature/my-change
# ... commit/push ...
gh pr create --base develop --head feature/my-change --title "feat: my-change" --body "…"
gh pr merge --squash --auto
```

### Release
```bash
git switch develop && git pull --rebase
git switch -c release/v0.4.0 && git push -u origin HEAD
gh pr create --base main --head release/v0.4.0 --title "Release v0.4.0" --body "…"
gh pr merge --squash --auto

# Sync main → develop
git fetch origin --prune
git switch -c sync/m2d origin/main && git push -u origin HEAD
gh pr create --base develop --head sync/m2d --title "Sync: main → develop" --body "Bring prod commit back."
gh pr merge --squash --auto
```

### Hotfix
```bash
git fetch origin --prune && git switch main && git pull --rebase
git switch -c hotfix/fix-urgent && git push -u origin HEAD
gh pr create --base main --head hotfix/fix-urgent --title "hotfix: urgent" --body "…"
gh pr merge --squash --auto

# Back-merge
git switch -c sync/hotfix origin/main && git push -u origin HEAD
gh pr create --base develop --head sync/hotfix --title "Back-merge hotfix main → develop" --body "…"
gh pr merge --squash --auto
```

---

## 6) Terraform stack (current)

> **Entry point:** root `main.tf` only. Everything else via modules.

### Modules in use now
- `modules/network`: VPC, public + private‑app + private‑db subnets (2 AZs), **free** S3/DynamoDB gateway endpoints, optional NAT GW (off by default).
- `modules/compute_app_host`: EC2 (Ubuntu 24.04), security group, optional EIP, **Docker + Caddy + Postgres (Docker) via user_data**.
- `modules/stack-ssm`: SSM association(s) for bootstrap/maintenance (extensible).

### Postgres policy
- **Mandatory** in the stack. Default: **Docker Postgres on the EC2 host**.
- Future: toggle to split out to its **own instance**. (Planned variable: `postgres_on_separate_host = true|false` and dependent module wiring).

### TLS choices
- If **premium/commercial SSL** material is available (planned inputs: cert/privkey/chain via SSM/Secrets), Caddy will be configured with it.  
- Otherwise, **Caddy auto‑issues** via ACME (Let’s Encrypt).

---

## 7) How to run locally (first time)

```bash
# Sanity
terraform fmt -recursive && terraform validate

# Initialize (uses backend in backend.tf)
terraform init

# Create/select workspace (one per branch is common)
terraform workspace list || true
terraform workspace select branch-$(git rev-parse --abbrev-ref HEAD) || terraform workspace new branch-$(git rev-parse --abbrev-ref HEAD)

# Plan (region comes from provider/env/vars; override with TF_VAR_region if needed)
terraform plan -out=tfplan.bin

# Apply (avoid on feature branches; prefer CI. If you must:)
terraform apply tfplan.bin
```

**If backend changed** (e.g., bucket/key):  
`terraform init -reconfigure`

---

## 8) Destroy (manual, safeguarded)

**GitHub Actions → “90 - Terraform Destroy (manual)”**  
Inputs:
- `confirm` (exact phrase)
- `workspace` (`default`/`prod`/`staging`…)
- `directory` (TF root; default `.`)
- `state_key_suffix` (e.g., `live/terraform.tfstate`)
- `plan_only` (`true` to preview)

**CLI parity**
```bash
terraform init \
  -backend-config="bucket=$TF_STATE_BUCKET" \
  -backend-config="key=$TF_STATE_KEY/live/terraform.tfstate" \
  -backend-config="region=$AWS_REGION" \
  -backend-config="use_lockfile=true" \
  -backend-config="encrypt=true"

terraform workspace select default || terraform workspace new default
terraform plan -destroy -out=tfplan.destroy
terraform destroy -auto-approve
```

---

## 9) Troubleshooting (field‑tested)

- **Repo 422 in Rulesets admin:** import the existing repo into TF before apply (the admin workflow does this automatically).
- **Provider version conflict:** remove `.terraform/` and `.terraform.lock.hcl`, then `terraform init -upgrade` **or** align provider constraints to AWS v6.x everywhere.
- **“Backend initialization required” after a local init:** run `terraform init -reconfigure` (state backend changed).
- **PR Gate “Expected” never clears:** ensure PR trigger includes `synchronize` and add `merge_group: {}`; the required check name must match exactly.
- **FF sync main→develop fails:** expected with squash merges; raise a **sync PR**.
- **Windows newlines warning on HTML:** safe to ignore or `git config core.autocrlf false`.

---

## 10) Roadmap (near‑term)
- **ECR (multi‑repo)** module + IAM to push from app repos.
- **SSM Documents** for deploy, db dump/restore, prune, notify (ported from v2 with `.tpl`).
- **Cloudflare** records module (toggle proxied), per‑app vhosts on Caddy.
- **Postgres backup to S3** (nightly dumps), and **restore** document.
- **Guardrails** on instance replacement (EBS snapshot/DLM, pre‑stop dump, data disks).
- **Split Postgres** to its own host (toggle), security groups & subnet placement wired.

---

## 11) Current repo structure (at time of writing)
```
.
├── backend.tf
├── providers.tf
├── data.tf
├── variables.tf
├── locals.tf
├── main.tf
├── outputs.tf
├── docs/
│   ├── git-workflow-mastery.md
│   ├── git-workflow-mastery.html
│   ├── infra-roadmap.md
│   ├── infra-roadmap.html
│   └── README.updated.md
├── modules/
│   ├── network/
│   ├── compute_app_host/
│   └── stack-ssm/
├── github/
│   ├── rulesets.tf
│   ├── providers.tf
│   └── variables.tf
├── bootstrap/
│   ├── main.tf
│   ├── providers.tf
│   └── variables.tf
└── .github/workflows/
    ├── 05-pr-quality-gate.yml
    ├── 10-terraform.yml
    ├── 90-terraform-destroy.yml
    └── 99-apply-github-rulesets.yml
```

---

## 12) What to change next (short checklist)
- [ ] Add ECR module(s) + outputs for app repos.
- [ ] Add SSM Documents & Associations (deploy, db-dump, db-restore).
- [ ] Add Cloudflare DNS module (enable controlled cutover).
- [ ] Add toggle/vars for premium SSL vs Caddy ACME.
- [ ] Add Postgres dump‑to‑S3 + lifecycle; restore path tested.
- [ ] Wire CI notifications (Slack/Resend) if desired.

---

### Appendix A — Commands we rely on often

**Verify branch content parity**
```bash
git fetch origin --prune
git rev-parse origin/main^{tree}; git rev-parse origin/develop^{tree}
```

**Open a PR from your current branch to develop**
```bash
gh pr create --base develop --head $(git branch --show-current) --title "…" --body "…"
```

**Create a sync PR (main→develop) after a release**
```bash
git fetch origin --prune
git switch -c sync/m2d origin/main && git push -u origin HEAD
gh pr create --base develop --head sync/m2d --title "Sync: main → develop" --body "Bring prod commit."
gh pr merge --squash --auto
```

---

**End of runbook.** Keep this file close; it’s the living map of the project.
