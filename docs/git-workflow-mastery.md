
# Git Workflow Mastery (Main ⇄ Develop, Features, Releases, Hotfixes)

_A friendly, end‑to‑end playbook that respects protected-branch rules and keeps your repo clean. Built from real pain._

---

## The “Don’t Flip Rules Again” Setup (Terraform)

Use this **stable** ruleset so PRs don’t hang on “Expected” checks and you don’t have to keep toggling protections.

> **What you get**
> - 1 approval on `main` and `develop`
> - Disallow force‑push & deletion on `main/develop`
> - Linear history on `main/develop` (use **squash merges**)
> - Require only **PR Quality Gate / pr‑quality** (non‑strict), so no “Expected” zombie status

```hcl
locals {
  # Must match your workflow check name exactly:
  pr_gate_context = "05 - PR Quality Gate / pr-quality"
}

# ---- MAIN ----
resource "github_repository_ruleset" "main" {
  repository  = var.repo_name
  name        = "main"
  target      = "branch"
  enforcement = "active"

  conditions { ref_name { include = ["refs/heads/main"] exclude = [] } }

  rules {
    pull_request {
      required_approving_review_count = 1
      dismiss_stale_reviews_on_push   = true
      require_code_owner_review       = false
      require_last_push_approval      = true
    }
    required_linear_history = true
    non_fast_forward        = true
    deletion                = true

    required_status_checks {
      strict_required_status_checks_policy = false
      required_check { context = local.pr_gate_context }
    }
  }
}

# ---- DEVELOP ----
resource "github_repository_ruleset" "develop" {
  repository  = var.repo_name
  name        = "develop"
  target      = "branch"
  enforcement = "active"

  conditions { ref_name { include = ["refs/heads/develop"] exclude = [] } }

  rules {
    pull_request {
      required_approving_review_count = 1
      dismiss_stale_reviews_on_push   = true
      require_code_owner_review       = false
      require_last_push_approval      = false
    }
    required_linear_history = true
    non_fast_forward        = true
    deletion                = true

    required_status_checks {
      strict_required_status_checks_policy = false
      required_check { context = local.pr_gate_context }
    }
  }
}
```

**Apply** via your workflow: `99 - Apply GitHub Rulesets` (must have a `workflow_dispatch` trigger).

---

## Golden Rules (so you keep 0 0 and your sanity)

1. **No direct commits** to `main` or `develop`. Everything goes through PRs.
2. **Feature branches** only off `develop`. Merge back into `develop` with **squash**.
3. **Release branches** off `develop`, PR into `main`, **squash**, then **immediately fast‑forward `develop` to main**.
4. **Hotfix branches** off `main`, PR into `main`, **squash**, then **immediately back‑merge `main → develop`**.
5. After **every** merge to `main`, run the **Back‑merge** step so `main` and `develop` converge to **0 0** (same commit).

> If you want “0 0” _always_: ensure `develop` only moves forward via back‑merges from `main` after releases/hotfixes. Don’t land extra commits on `develop` that aren’t in `main` yet.

---

## Everyday Feature Flow

```bash
# Start clean on develop
git fetch origin --prune
git switch develop
git pull --rebase

# Create feature branch from develop
git switch -c feature/my-change

# Edit → stage → commit
git add <files>
git commit -m "feat: short description"

# First push (sets upstream with HEAD)
git push -u origin HEAD

# Open PR (base=develop, compare=feature/my-change)
gh pr create --base develop --head feature/my-change \
  --title "feat: my-change" \
  --body "Short description"

# After CI passes and you have 1 approval:
gh pr merge --squash --auto   # or merge from the UI

# Sync local for next work
git switch develop && git pull --rebase
git branch -d feature/my-change
```

---

## Release Flow (Develop → Main)

```bash
# Cut release from latest develop
git fetch origin --prune
git switch develop && git pull --rebase
git switch -c release/v0.4.0
git push -u origin HEAD

# PR (base=main, compare=release/v0.4.0) → squash merge when green
gh pr create --base main --head release/v0.4.0 \
  --title "Release v0.4.0" \
  --body "Cut from develop; includes ..."

# After merging to main: fast-forward develop to main (keeps 0 0)
git switch develop
git fetch origin --prune
git merge --ff-only origin/main
git push

# (Optional) delete release branch
git push origin :release/v0.4.0
```

---

## Hotfix Flow (Main → Main, then Back‑merge)

```bash
# Branch off production
git fetch origin --prune
git switch main && git pull --rebase
git switch -c hotfix/fix-bug
git push -u origin HEAD

# PR (base=main, compare=hotfix/fix-bug) → squash merge when green
# CI on main applies infra

# Back-merge to develop so the fix isn't lost
git switch develop && git pull --rebase
git merge --no-ff origin/main
git push
```

---

## Conflict Resolution: “ours” vs “theirs”

During merge/rebase, choose a side file‑by‑file to resolve fast:

```bash
# keep your side (the branch you have checked out)
git checkout --ours path/to/file && git add path/to/file

# keep the incoming side (the branch you’re merging/rebasing onto)
git checkout --theirs path/to/file && git add path/to/file
```

Finish the operation:

```bash
# if merging:
git commit

# if rebasing:
git rebase --continue

# bail out:
git merge --abort   # or: git rebase --abort
```

**When to choose which?**
- **Release PR into main**: prefer **theirs=main** if release accidentally diverged; otherwise review.
- **Back‑merge main → develop**: usually keep **theirs=main** to make develop match production.
- **Rebase feature onto develop**: usually keep **ours** for your feature files; keep **theirs** for shared files that changed upstream unless your change is intentional.

---

## Keep `main` and `develop` at 0 0

**After every merge to main:**
```bash
git switch develop
git fetch origin --prune
git merge --ff-only origin/main
git push
```

**Verify 0 0:**
```bash
git fetch origin --prune
git rev-list --left-right --count origin/main...origin/develop
# expect: 0       0
```

If it isn’t 0 0, someone pushed extra commits to `develop`. Don’t force‑push. Either:
- **Revert** those commits via a PR to develop, or
- Cut a new **release** so the changes go to main, then fast‑forward as above.

---

## Clean Up Branches

Delete merged remote branches (safe):

```bash
# delete one
git push origin :feature/my-old-branch

# delete many except main/develop
for b in $(git ls-remote --heads origin | awk '{print $2}' | sed 's@refs/heads/@@' | grep -vE '^(main|develop)$'); do
  git push origin :$b || true
done
```

Delete locals (safe):
```bash
for lb in $(git for-each-ref --format='%(refname:short)' refs/heads | grep -vE '^(main|develop)$'); do
  git branch -D "$lb" || true
done
```

---

## CI/Checks Naming (avoid “Expected” hangs)

- Your workflow that runs on **pull_request** must publish a check **named exactly**:  
  `05 - PR Quality Gate / pr-quality`
- Keep `strict_required_status_checks_policy = false` so GitHub doesn’t block on a missing/renamed check.
- If you rename the workflow/job, update the `locals.pr_gate_context` accordingly and re-apply.

---

## Fast “Stuck” Playbook

- **Remote ahead**: `git pull --rebase`
- **No upstream**: `git push -u origin HEAD`
- **Unstaged changes blocking pull**: `git stash -u -m wip && git pull --rebase && git stash pop`
- **Conflict everywhere**: take one side fast (`--ours` or `--theirs`), commit, then follow‑up PRs can refine.
- **PR not showing update**: push an empty commit to retrigger: `git commit --allow-empty -m "ci: nudge" && git push`

---

## Appendix: End‑to‑End Example (Feature → Develop → Main)

```bash
# start feature
git switch develop && git pull --rebase
git switch -c feature/add-widget
# ...code...
git add . && git commit -m "feat(widget): add thing"
git push -u origin HEAD
gh pr create --base develop --head feature/add-widget --title "feat(widget): add thing" --body "…"
gh pr merge --squash --auto

# release to main
git switch develop && git pull --rebase
git switch -c release/v0.4.1 && git push -u origin HEAD
gh pr create --base main --head release/v0.4.1 --title "Release v0.4.1" --body "…"
gh pr merge --squash --auto

# back-merge to keep 0 0
git switch develop && git fetch origin --prune
git merge --ff-only origin/main && git push

# verify
git fetch origin --prune
git rev-list --left-right --count origin/main...origin/develop  # -> 0 0
```
