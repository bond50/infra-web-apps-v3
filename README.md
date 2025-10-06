<!--
###############################################################
# README.md
# Purpose:
#  - Quickstart for this Terraform + GitHub Actions repo.
#  - How to bootstrap backend + OIDC.
#  - How PR Quality Gate and Apply-on-main work.
#  - Links to CONTRIBUTING and branch rulesets.
###############################################################
-->

# Infra Repo — Terraform + GitHub Actions (OIDC, S3 backend)

This repo uses:
- **S3** (versioned, encrypted) for Terraform state
- **DynamoDB** for state locking
- **AWS IAM OIDC** trust with **GitHub Actions** (no long-lived keys)
- Two workflows:
  - **05 - PR Quality Gate** → fmt, validate, TFLint, Checkov, Plan (PRs only)
  - **10 - Terraform** → plan on all branches/PRs, **apply only on push to `main`** (gated by Environment: `production`)

> Branch model: `main`, `develop`, `feature/*`, `release/*`, `hotfix/*` (see **[CONTRIBUTING.md](CONTRIBUTING.md)**)


---

## 1) One-time Bootstrap (creates backend + OIDC + repo variables)

<!--
Run this once per AWS account/region to prepare the backend and CI trust.
Assumes you've stored bootstrap AWS keys in repo secrets.
-->

### Prerequisites (repo settings)
- **Secrets** → add temporary AWS keys (delete after success):
  - `AWS_ACCESS_KEY_ID`
  - `AWS_SECRET_ACCESS_KEY`
- **(Optional) Secret** → `GH_ADMIN_TOKEN` (repo admin PAT) if you want Terraform to populate repo variables automatically.  
  *You can skip this if you prefer to set variables manually.*
- **Variables** (not secret):
  - `AWS_REGION` (e.g., `us-east-1`)

### Run the bootstrap workflow
GitHub → **Actions** → **“00 - Bootstrap AWS Backend”** → **Run workflow** and fill inputs:
- `bucket_name` → globally unique (e.g., `my-tfstate-12345`)
- `dynamodb_table_name` → e.g., `tf-locks-my-tfstate-12345`
- `tf_state_key` → e.g., `infra/terraform.tfstate`
- `github_owner` → e.g., `bond50`
- `github_repo` → this repository name (no owner)
- `project_name` → short tag prefix (e.g., `web-apps`)

**What it creates**
- S3 bucket + versioning + encryption + TLS-only policy
- DynamoDB table (on-demand) for tfstate locks
- OIDC provider for `token.actions.githubusercontent.com`
- IAM role `*-gha` assumable by this repo via OIDC
- GitHub repo variables (if PAT given):
  - `AWS_REGION`, `AWS_ROLE_ARN`, `TF_STATE_BUCKET`, `TF_STATE_TABLE`, `TF_STATE_KEY`

> After success, **delete** the temporary AWS keys from repo secrets. OIDC is now in place.


---

## 2) Daily Flow (PRs and merges)

- **Feature work** → branch from `develop` → open PR to `develop`
  - **05 - PR Quality Gate** runs on the PR (must be green)
- **Release** → branch `release/*` from `develop` → PR to `main`
- **Hotfix** → branch `hotfix/*` from `main` → PR to `main`
- **Apply** happens **only on push to `main`**, gated by **Environment `production`** (set reviewers in Settings → Environments)

See **[CONTRIBUTING.md](CONTRIBUTING.md)** for ruleset clickthroughs and PR checklist.


---

## 3) Local commands (nice to run before pushing)

```bash
# Format + validate
terraform fmt -recursive && terraform validate

# Lint (downloads plugins from .tflint.hcl)
tflint --init && tflint -f compact

# Scan policies
checkov -d . --framework terraform
```

Optional pre-commit hooks:
```bash
pip install pre-commit
pre-commit install
pre-commit run -a
```


---

## 4) Folder Structure

```text
.
├── backend.tf
├── providers.tf
├── data.tf
├── variables.tf
├── locals.tf
├── main.tf
├── outputs.tf
├── data-ami.tf
│
├── modules/
│   ├── network/
│   ├── security-group/
│   ├── ecr-repository/
│   ├── ssm-params/
│   ├── ssm-param-mutable/
│   ├── github-ci/
│   └── db-backup/
│
├── bootstrap/
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
│
├── .github/
│   ├── workflows/
│   │   ├── 05-pr-quality-gate.yml
│   │   └── 10-terraform.yml
│   └── pull_request_template.md
│
├── .tflint.hcl
├── .checkov.yml
├── .pre-commit-config.yaml
├── CODEOWNERS
└── README.md
```


---

## 5) Troubleshooting (common first-run issues)

- **OIDC provider already exists**  
  Another repo/account created it earlier. That’s OK. We import/manage where needed.

- **GitHub Actions variable already exists**  
  Use Terraform import or let CI manage after you delete the duplicate in repo settings.

- **DynamoDB table or S3 bucket already exists**  
  Import into state or pick a new name. Buckets are global; use a unique suffix.

- **`configure-aws-credentials` cannot resolve STS endpoint**  
  Ensure region value looks like `us-east-1` and there’s no typo like `us-east1`.

- **Plan never applies**  
  Only applies on **push to `main`**. PRs and non-main branches do **plan only**.

If you get stuck, open a PR and let **05 - PR Quality Gate** annotate findings, or ping CODEOWNERS.


---

## 6) Links

- **Contributor guide** → [CONTRIBUTING.md](CONTRIBUTING.md)  
- **Branch rulesets one-pagers** → [Rulesets-Overview.md](Rulesets-Overview.md)  
  - [main](Ruleset-main.md) • [develop](Ruleset-develop.md) • [release/*](Ruleset-release-star.md) • [hotfix/*](Ruleset-hotfix-star.md)
