# Git Workflow Mastery — Main ⇄ Develop (Features • Releases • Hotfixes)

_A dependable, squash‑only flow with protected branches, CI gates, and “sync main → develop”._

---

## Quick Decision Guide

-   **New work (Features):** `feature/*` off `develop` → PR to `develop` → **squash**.
-   **Ship to Production (Release):** `release/*` off `develop` → PR to `main` → **squash** → **sync PR `main → develop`**.
-   **Emergency Fix:** `hotfix/*` off `main` → PR to `main` → **squash** → **back‑merge `main → develop`** (sync PR).

> **Why a sync PR?** Squash merges create new commits, so a fast‑forward from `main` to `develop` is usually impossible. Use a small **sync branch** from `origin/main` and PR it into `develop`.

---

## Start Here (every time)

```bash
git fetch origin --prune                # update remote refs; remove deleted ones
git switch develop                      # move to develop
git pull --rebase                       # update while keeping a straight history
```

**Flag helpers**

-   `--rebase`: replay your local commits on top of remote, avoiding merge commits.
-   `--prune`: drop remote branches that were deleted on the server.

---

## Parity & Quick Proofs

Use **content** parity, not commit counts (squash creates new SHAs).

```bash
git fetch origin --prune
git rev-parse origin/main^{tree}; git rev-parse origin/develop^{tree}
# If the two tree hashes are identical, content is identical (✅).

# A quick diff if they differ:
git diff --name-status origin/main origin/develop
```

---

## Cheatsheet (frequently used)

-   `git merge --ff-only <branch>` → **fast‑forward only** (abort if a merge commit is needed).
-   `git merge --no-ff <branch>` → **force** a merge commit (avoid on protected branches).
-   `git push -u origin HEAD` → **set upstream** on first push.
-   `gh pr create --base X --head Y` → open a PR from **Y → X**.
-   `gh pr merge --squash --auto` → squash‑merge automatically when green + approved.
-   **Pick a side in conflicts** during merge/rebase:
    ```bash
    git checkout --ours path/to/file   # keep current branch version
    git checkout --theirs path/to/file # keep incoming branch version
    git add path/to/file
    ```
-   Finish or bail:
    ```bash
    git commit              # finish merge
    git rebase --continue   # finish step
    git merge --abort       # or: git rebase --abort
    ```

---

## Feature Flow

```bash
# 1) Start clean on develop
git fetch origin --prune
git switch develop
git pull --rebase

# 2) Create feature branch
git switch -c feature/my-change

# 3) Work, commit, push
git add .
git commit -m "feat: my change"
git push -u origin HEAD

# 4) PR: feature → develop (squash)
gh pr create --base develop --head feature/my-change --title "feat: my change" --body "…"
gh pr merge --squash --auto

# 5) Clean + resync local
git switch develop && git pull --rebase
git branch -d feature/my-change
```

---

## Release Flow (squash‑friendly)

```bash
# 1) Cut release from latest develop
git switch develop && git pull --rebase
git switch -c release/v0.4.0
git push -u origin HEAD

# 2) PR: release → main (squash)
gh pr create --base main --head release/v0.4.0 --title "Release v0.4.0" --body "…"
gh pr merge --squash --auto

# 3) Sync main → develop (because squash prevents FF)
git fetch origin --prune
git switch -c sync/m2d origin/main
git push -u origin HEAD
gh pr create --base develop --head sync/m2d --title "Sync: main → develop" --body "Bring production commit back."
gh pr merge --squash --auto

# 4) Verify content parity (0 0 is not required with squashes)
git fetch origin --prune
git rev-parse origin/main^{tree}; git rev-parse origin/develop^{tree}
git diff --name-status origin/main origin/develop || true

# 5) Tidy
git switch develop && git pull --rebase
git push origin :sync/m2d
git push origin :release/v0.4.0
```

**If `--ff-only` fails** after a release: expected. Use the **sync PR** as above.

---

## Release (Option A): Cherry‑pick from production (when develop has mixed readiness)

Start from `main` and pick only ready commits.

```bash
# From a clean repo
git fetch origin --prune
git switch -c release/v0.4.0 origin/main                 # start release from production

# See what's new on develop vs main
git log --oneline --no-merges origin/main..origin/develop

# Cherry-pick only the commits you want (one by one; resolve conflicts as needed)
git cherry-pick <sha1> <sha2>                            # use squashed PR SHAs

git push -u origin HEAD                                  # publish release branch

# PR to main and squash-merge (deploy)
gh pr create --base main --head release/v0.4.0 --title "Release v0.4.0" --body "Cherry-picked: <list>"
gh pr merge --squash --auto

# Sync main → develop (tiny PR because of squash)
git fetch origin --prune
git switch -c sync/m2d origin/main
git push -u origin HEAD
gh pr create --base develop --head sync/m2d --title "Sync: main → develop" --body "Bring production commit into develop."
gh pr merge --squash --auto
```

---

## Release (Option B): Stabilize on a release branch off develop

If you prefer, cut `release/*` from `develop` then **revert** unready commits **on the release branch** before PR to `main`.

```bash
git fetch origin --prune
git switch develop && git pull --rebase
git switch -c release/v0.4.0

# Revert unready commit(s) (use squashed PR SHAs from develop)
git revert <shaUnreadyA> <shaUnreadyB>   # or: git revert --no-commit ... && git commit -m "chore: drop unready"
git push -u origin HEAD

# PR to main → squash → sync main → develop (same as above)
```

---

## Hotfix Flow

```bash
# 1) Branch from production
git fetch origin --prune && git switch main && git pull --rebase
git switch -c hotfix/fix-urgent-issue
git push -u origin HEAD

# 2) PR: hotfix → main (squash)
gh pr create --base main --head hotfix/fix-urgent-issue --title "hotfix: fix urgent issue" --body "…"
gh pr merge --squash --auto

# 3) Back-merge main → develop via sync PR
git fetch origin --prune
git switch -c sync/hotfix origin/main
git push -u origin HEAD
gh pr create --base develop --head sync/hotfix --title "Back-merge hotfix main → develop" --body "…"
gh pr merge --squash --auto
```

---

## Conflict Playbook (fast + safe)

**Preview conflicts with main (no changes made):**

```bash
git fetch origin --prune
git switch -c _preview origin/main
git merge --no-commit --no-ff origin/<branch>
git diff --name-only --diff-filter=U   # list conflicted files
git merge --abort && git branch -D _preview
```

**Resolve during merge (pick per file):**

```bash
git checkout --ours path/to/file   && git add path/to/file     # keep current branch
git checkout --theirs path/to/file && git add path/to/file     # keep incoming
git commit
```

**Sync PR conflicts (main → develop):**

```bash
git switch -c sync/m2d origin/main
git merge origin/develop            # on sync branch, 'ours' = main
# resolve, prefer ours where appropriate
git commit && git push
```

---

## CI & Rules You Rely On (make them deterministic)

**Required check name:** `05 - PR Quality Gate / pr-quality`  
**Strong trigger block** (prevents “Expected” hangs):

```yaml
on:
    pull_request:
        branches: ['**'] # run for PRs to any base branch
        types: [opened, synchronize, reopened] # rerun on every PR update
    merge_group: {} # report status for merge queue/auto-merge
```

**If a duplicate workflow shares the same `name:`** it can cause “green but still expected”. Keep only **one** file with that name.

**Rulesets (Terraform)**

-   `required_approving_review_count = 1`
-   `required_linear_history = true`
-   `non_fast_forward = true`
-   `required_status_checks.strict_required_status_checks_policy = false` _(non‑strict to avoid zombie “Expected”)_
-   **Squash only** (repository‑level):
    ```hcl
    resource "github_repository" "repo" {
      name                   = var.repo_name
      allow_merge_commit     = false
      allow_rebase_merge     = false
      allow_squash_merge     = true
      delete_branch_on_merge = true
    }
    ```

**Admin workflow (manual apply) must import the repo before apply** to avoid 422:

```yaml
- name: Pre-import repository
  env:
      TF_VAR_github_owner: ${{ github.repository_owner }}
      TF_VAR_github_token: ${{ secrets.GH_TOKEN_ADMIN }}
  run: |
      terraform state show github_repository.repo >/dev/null 2>&1 || \
        terraform import -input=false github_repository.repo "${{ github.event.repository.name }}"
```

**S3 backend (warning‑free):**

```bash
terraform init \
  -backend-config="bucket=$TF_STATE_BUCKET" \
  -backend-config="key=$TF_STATE_KEY/github-rulesets.tfstate" \
  -backend-config="region=$AWS_REGION" \
  -backend-config="use_lockfile=true" \
  -backend-config="encrypt=true"
```

**Repo variables you must have set (via bootstrap/TF or repo settings):**

-   `AWS_REGION`, `AWS_ROLE_ARN`, `TF_STATE_BUCKET`, `TF_STATE_KEY`

---

## Clean‑ups

```bash
# Delete a remote branch
git push origin :branch/name

# Bulk delete merged remotes (except main/develop)
for b in $(git ls-remote --heads origin | awk '{print $2}' | sed 's@refs/heads/@@' | grep -vE '^(main|develop)$'); do
  git push origin :"$b" || true
done

# Delete local branches (except main/develop)
for lb in $(git for-each-ref --format='%(refname:short)' refs/heads | grep -vE '^(main|develop)$'); do
  git branch -D "$lb" || true
done
```

---

## FAQ

-   **Why does `rev-list` show non‑zero on both sides after sync?**  
    Because squash creates new SHAs; histories diverge. Use **tree hashes** or `git diff` for content parity.
-   **“PR Quality Gate — Expected” won’t clear.**  
    Ensure `pull_request.types` include `synchronize` and you have `merge_group: {}`. Also remove any legacy branch protection that still requires the check.
-   **Fast‑forward from `main` to `develop` fails.**  
    Expected with squash. Use the **sync PR**.

---

## Terraform Destroy (Manual, Safeguarded)

**When to use:** only for tearing down non-prod sandboxes or during a controlled migration.  
**Protection:** The workflow requires a typed confirmation, runs only on `main`, and uses the `production` environment (reviewers must approve).

### Run it (GitHub UI → Actions → “90 - Terraform Destroy (manual)”)

Inputs:

-   **confirm**: `I UNDERSTAND THIS WILL DESTROY ALL RESOURCES` (exactly)
-   **workspace**: e.g., `default` / `prod` / `staging`
-   **directory**: path to your Terraform root (default `.`)
-   **state_key_suffix**: appended to `TF_STATE_KEY`, e.g., `live/terraform.tfstate`
-   **plan_only**: `true` to review the destroy plan without destroying

### CLI parity (if you must do it locally)

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

---
```
