<!--
###############################################################
# Ruleset-main.md
# Purpose:
#  - Click-through instructions to configure the "main" ruleset.
#  - Values are listed in the exact order the GitHub UI shows them.
###############################################################
-->

# Ruleset — `main` (production, strict)

## Ruleset Basics
- **Ruleset Name:** `main`
- **Enforcement status:** **Enabled**
- **Bypass list:** *Empty* (optionally add an Owners “break-glass” team)

## Target branches
- **Branch targeting criteria:** `main`

## Rules (exact UI order)

### Branch rules
- **Restrict creations:** **Off**  <!-- allow normal merges/refs -->
- **Restrict updates:** **Off**
- **Restrict deletions:** **On** ✅  <!-- protect from accidental deletion -->
- **Require linear history:** **On** ✅  <!-- pair with squash/rebase -->
- **Require deployments to succeed:** **Off**  <!-- apply runs after merge via push to main -->
- **Require signed commits:** **Optional**  <!-- enable only if contributors sign commits -->

### Pull request rules
- **Require a pull request before merging:** **On** ✅
  - **Required approvals:** **2**  <!-- use 1 if you prefer faster merges -->
  - **Dismiss stale approvals:** **On** ✅
  - **Require review from Code Owners:** **On** ✅ *(if you have CODEOWNERS; else Off)*
  - **Require approval of the most recent reviewable push:** **On** ✅
  - **Require conversation resolution before merging:** **On** ✅
  - **Automatically request Copilot code review:** **Optional**

### Allowed merge methods
- **Allow merge commits:** **Off**
- **Allow squash merging:** **On** ✅
- **Allow rebase merging:** **On** *(optional)*

### Status checks
- **Require status checks to pass:** **On** ✅
  - **Require branches to be up to date before merging:** **On** ✅
  - **Do not require status checks on creation:** **Off**
  - **Select checks:** tick **`05 - PR Quality Gate / pr-quality`**

### Force pushes / Code scanning
- **Block force pushes:** **On** ✅
- **Require code scanning results:** **Off** *(unless you use GitHub code scanning; Checkov runs in CI)*
- **Automatically request Copilot code review:** **Optional**
