<!--
###############################################################
# Ruleset-hotfix-star.md
# Purpose:
#  - Click-through instructions to configure the "hotfix/*" ruleset.
#  - Values are listed in the exact order the GitHub UI shows them.
###############################################################
-->

# Ruleset — `hotfix/*` (urgent from main, fast but safe)

## Ruleset Basics
- **Ruleset Name:** `hotfix/*`
- **Enforcement status:** **Enabled**
- **Bypass list:** *Empty*

## Target branches
- **Branch targeting criteria:** `hotfix/*`

## Rules (exact UI order)

### Branch rules
- **Restrict creations:** **Off**
- **Restrict updates:** **Off**
- **Restrict deletions:** **On** ✅
- **Require linear history:** **On** ✅
- **Require deployments to succeed:** **Off**
- **Require signed commits:** **Optional**

### Pull request rules
- **Require a pull request before merging:** **On** ✅
  - **Required approvals:** **1** ✅  <!-- keep hotfixes swift but reviewed -->
  - **Dismiss stale approvals:** **On** ✅
  - **Require review from Code Owners:** **Optional**
  - **Require approval of the most recent reviewable push:** **On** ✅
  - **Require conversation resolution before merging:** **On** ✅
  - **Automatically request Copilot code review:** **Optional**

### Allowed merge methods
- **Merge commits:** **Off**
- **Squash:** **On** ✅
- **Rebase:** **On** *(optional)*

### Status checks
- **Require status checks to pass:** **On** ✅
  - **Require branches to be up to date before merging:** **Optional**
  - **Do not require status checks on creation:** **Off**
  - **Select checks:** **`05 - PR Quality Gate / pr-quality`**

### Force pushes / Code scanning
- **Block force pushes:** **On** ✅
- **Require code scanning results:** **Off** *(unless configured)*
- **Automatically request Copilot code review:** **Optional**
