<!--
###############################################################
# Ruleset-release-star.md
# Purpose:
#  - Click-through instructions to configure the "release/*" ruleset.
#  - Values are listed in the exact order the GitHub UI shows them.
###############################################################
-->

# Ruleset — `release/*` (stabilization, like main)

## Ruleset Basics
- **Ruleset Name:** `release/*`
- **Enforcement status:** **Enabled**
- **Bypass list:** *Empty*

## Target branches
- **Branch targeting criteria:** `release/*`

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
  - **Required approvals:** **2**  <!-- recommended for releases -->
  - **Dismiss stale approvals:** **On** ✅
  - **Require review from Code Owners:** **On** ✅
  - **Require approval of the most recent reviewable push:** **On** ✅
  - **Require conversation resolution before merging:** **On** ✅
  - **Automatically request Copilot code review:** **Optional**

### Allowed merge methods
- **Merge commits:** **Off**
- **Squash:** **On** ✅
- **Rebase:** **On** *(optional)*

### Status checks
- **Require status checks to pass:** **On** ✅
  - **Require branches to be up to date before merging:** **On** ✅
  - **Do not require status checks on creation:** **Off**
  - **Select checks:** **`05 - PR Quality Gate / pr-quality`**

### Force pushes / Code scanning
- **Block force pushes:** **On** ✅
- **Require code scanning results:** **Off** *(unless configured)*
- **Automatically request Copilot code review:** **Optional**
