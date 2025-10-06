<!--
###############################################################
# CONTRIBUTING.md
# Purpose:
#  - Document our GitFlow-lite workflow and daily developer steps.
#  - Link to the Branch Rulesets one-pagers for exact GitHub UI settings.
#  - Summarize CI workflows, branch protections, and PR checklist.
###############################################################
-->

# Contributing Guide (GitFlow‑lite)

> **Branches**
> - `main` → production (protected; only CI applies on push to `main`)
> - `develop` → integration branch (default PR target for features)
> - `feature/*` → short-lived branches from `develop`
> - `release/*` → stabilization branches cut from `develop`
> - `hotfix/*` → urgent fixes cut from `main`

---

## 📚 Branch Rulesets — Clickthrough Guides

Use these one-pagers (exact GitHub UI order) when creating Branch Rulesets in **Settings → Rules → New branch ruleset**:

- **Overview / prerequisites** → [Rulesets-Overview.md](sandbox:/mnt/data/Rulesets-Overview.md)
- **Production** → [Ruleset-main.md](sandbox:/mnt/data/Ruleset-main.md)
- **Integration** → [Ruleset-develop.md](sandbox:/mnt/data/Ruleset-develop.md)
- **Release** → [Ruleset-release-star.md](sandbox:/mnt/data/Ruleset-release-star.md)
- **Hotfix** → [Ruleset-hotfix-star.md](sandbox:/mnt/data/Ruleset-hotfix-star.md)

> No ruleset for `feature/*` (keeps iteration fast; safety enforced at PR time).

---

## 🚦 CI/CD — What runs where

- **05 - PR Quality Gate** (PRs only; no apply)  
  Triggers on PRs targeting: `develop`, `main`, `release/*`, `hotfix/*`  
  Steps: `terraform fmt` → `terraform validate` → **TFLint** → **Checkov** → `terraform plan` (no lock/refresh) → upload artifact

- **10 - Terraform** (plan on branches/PRs; **apply only on pushes to `main`**)  
  Triggers on pushes to: `feature/*`, `develop`, `release/*`, `hotfix/*`, `main`  
  Triggers on PRs into: `develop`, `main`, `release/*`, `hotfix/*`  
  - Always **plans**  
  - **Apply** step runs **only** when: `event == push` **and** `ref == refs/heads/main`  
  - Apply is gated by **Environment `production`** (add approvers in *Settings → Environments → production*)

---

## 🧭 Day‑to‑day Flow

### Start a feature
```bash
git checkout develop && git pull                       # always branch from develop
git checkout -b feature/WEB-123-login                   # create feature branch
# ... commit work ...
git push -u origin feature/WEB-123-login                # push remote
```

### Open a PR (feature → develop)
- Target branch: **`develop`**
- Required check: **05 - PR Quality Gate / pr-quality** must pass
- Request reviewers (and CODEOWNERS if applicable)

### Release
```bash
git checkout develop && git pull
git checkout -b release/2025.10.0
git push -u origin release/2025.10.0
# Open PR: release/*  →  main  (requires approvals + checks)
```
After merge to `main`, CI **applies**. Then **back‑merge** `main → develop`:
```bash
git checkout develop && git pull
git merge --no-ff origin/main
git push
```

### Hotfix
```bash
git checkout main && git pull
git checkout -b hotfix/2025.10.1-ecs-timeout
git push -u origin hotfix/2025.10.1-ecs-timeout
# Open PR: hotfix/*  →  main
```
After merge/apply, **back‑merge** `main → develop`.

---

## ✅ PR Checklist (Terraform)

- [ ] `terraform fmt -recursive` is clean
- [ ] `terraform validate` passes
- [ ] `tflint --init && tflint` passes
- [ ] `checkov -d . --framework terraform` passes (or findings justified)
- [ ] Plan artifact reviewed (CI upload)
- [ ] CODEOWNERS approvals obtained (if applicable)

---

## 🔐 Branch Protection Summary (quick reference)

> Create rulesets for: `main`, `develop`, `release/*`, `hotfix/*`.  
> Key settings (see one-pagers for full checklists):

- **Require PR before merging:** On (main/develop/release/hotfix)
- **Approvals:** main=2 (or 1), develop=1, release=2, hotfix=1
- **Dismiss stale approvals:** On
- **Require most recent push approved:** On
- **Require conversations resolved:** On
- **Require status checks:** On → select **“05 - PR Quality Gate / pr-quality”**
- **Require linear history:** On (use Squash/Rebase; disable merge commits)
- **Block force pushes:** On
- **Restrict deletions:** On
- **Signed commits:** Optional
- **Require deployments to succeed:** Off (apply is post‑merge on main)

---

## 🗂 Recommended Folder Structure

```text
.
├── backend.tf                         # terraform backend { s3 {} } (values injected by CI)
├── providers.tf                       # provider "aws" { region = var.region } etc.
├── variables.tf                       # shared variables
├── locals.tf                          # shared locals
├── main.tf                            # root resources & module wiring
├── outputs.tf                         # root outputs
├── data.tf                            # data "aws_caller_identity" etc.
├── data-ami.tf                        # AMI lookups (if used)
│
├── modules/
│   ├── network/                       # VPC/Subnets/Routes (yours)
│   ├── security-group/                # NEW: reusable SG module
│   ├── ecr-repository/                # NEW: ECR repo module
│   ├── ssm-params/                    # NEW: param store (plain/secure)
│   ├── ssm-param-mutable/             # NEW: ignores value drift by design
│   ├── github-ci/                     # NEW: reusable CI/OIDC helpers
│   └── db-backup/                     # NEW: KMS + S3 + policy attach
│
├── bootstrap/                         # one-time state backend/OIDC bootstrap
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf                     # (optional) export created ARNs/names
│
├── .github/
│   ├── workflows/
│   │   ├── 05-pr-quality-gate.yml     # PR checks: fmt/validate/tflint/checkov/plan
│   │   └── 10-terraform.yml           # plan on branches, apply on main
│   ├── CODEOWNERS                     # optional: code ownership
│   └── pull_request_template.md       # optional: PR template
│
├── scripts/                           # helper scripts (optional)
└── README.md                          # project overview / quickstart
```

---

## 🧰 Tool Versions (pinned today)
- Terraform CLI: `1.13.3`
- hashicorp/setup-terraform: `v3`
- actions/checkout: `v5`
- aws-actions/configure-aws-credentials: `v5`
- terraform-linters/setup-tflint: `v5` (TFLint `v0.59.1`)
- actions/setup-python: `v6` (Python `3.13`)
- actions/upload-artifact: `v4`


---

## 🔄 Updating plugins & tool versions (TFLint, Checkov, Terraform)

<!--
Keep versions pinned so CI is reproducible. Bump intentionally and test in a PR.
This section shows HOW to bump and WHERE to change things.
-->

### 1) TFLint rulesets (Terraform language + AWS)
Files to edit: **.tflint.hcl**
```hcl
plugin "terraform" {
  enabled = true
  version = "0.13.0"   # <- bump here when a new release is vetted
  source  = "github.com/terraform-linters/tflint-ruleset-terraform"
}

plugin "aws" {
  enabled = true
  version = "0.43.0"   # <- bump here when a new release is vetted
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}
```

Local test after bump:
```bash
tflint --version                     # ensure a recent TFLint (>= 0.42)
tflint --init                        # downloads the pinned plugin versions
tflint -f compact                    # run locally and review findings
```

Commit only **.tflint.hcl**. CI will re-download the new pinned versions during **05 - PR Quality Gate**.

### 2) Checkov (security scanner)
File to edit: **.github/workflows/05-pr-quality-gate.yml**
```yaml
- name: Install Checkov
  run: pip install --quiet "checkov==3.2.474"   # <- bump version here
```
Local test after bump:
```bash
python3 -m pip install "checkov==<NEW>"
checkov -d . --framework terraform
```

### 3) Terraform CLI
File to edit: **.github/workflows/05-pr-quality-gate.yml** and **10-terraform.yml**
```yaml
- name: Setup Terraform
  uses: hashicorp/setup-terraform@v3
  with:
    terraform_version: 1.13.3   # <- bump when you adopt a newer stable
```
Local test after bump:
```bash
tfenv install 1.<NEW> && tfenv use 1.<NEW>    # if you use tfenv
terraform version
terraform fmt -recursive && terraform validate
```

### 4) Actions (checkout / aws creds / tflint / python / artifact)
We pin by **major** in workflows. To adopt a new **major**:
- `actions/checkout@v5`
- `aws-actions/configure-aws-credentials@v5`
- `terraform-linters/setup-tflint@v5`
- `actions/setup-python@v6`
- `hashicorp/setup-terraform@v3`
- `actions/upload-artifact@v4`

> When bumping majors, open a PR, let **PR Quality Gate** run, and verify all steps succeed.

### 5) Suggested bump flow
```bash
# Create a bump branch
git checkout -b chore/bump-lint-scan-versions

# Edit versions:
#   - .tflint.hcl              (terraform & aws plugins)
#   - .github/workflows/*.yml  (checkov, terraform_version, actions if needed)

# Test locally (optional):
tflint --init && tflint -f compact
python3 -m pip install "checkov==<NEW>" && checkov -d . --framework terraform

# Commit & PR
git commit -am "chore(ci): bump TFLint rulesets / Checkov / Terraform CLI"
git push -u origin chore/bump-lint-scan-versions
# Open PR to develop; PR Quality Gate will validate
```

> Tip: You can automate version bumps with Renovate/Dependabot later. Start manual until the repo stabilizes.
