<!--
###############################################################
# Rulesets-Overview.md
# Purpose:
#  - High-level overview of our GitFlow-lite branch policy.
#  - Which rulesets to create and why.
#  - Quick prerequisites before configuring rules.
###############################################################
-->

# GitHub Branch Rulesets — Overview (GitFlow-lite)

> **Branches used**
> - `main` → production (protected; only CI applies on push to `main`)
> - `develop` → integration
> - `feature/*` → short-lived work branches (no ruleset)
> - `release/*` → stabilization for a release
> - `hotfix/*` → urgent fixes from `main`

---

## Prerequisites
- Create `develop` if missing:
  ```bash
  git checkout -b develop && git push -u origin develop
  ```
- Let the workflow **“05 - PR Quality Gate”** run once so it appears under **Select checks**.

---

## Rulesets to create (in GitHub → Settings → Rules → New branch ruleset)
1. **main** — production, strict
2. **develop** — integration, strong
3. **release/*** — stabilization, same strictness as `main`
4. **hotfix/*** — urgent fixes, fast but safe
5. **feature/*** — **no ruleset** (keeps iteration fast; safety enforced on PR to protected branches)

> Each ruleset file in this bundle walks you through the **exact UI order**.
