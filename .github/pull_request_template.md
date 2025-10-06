<!--
###############################################################
# .github/pull_request_template.md
# Purpose:
#  - Standardize PR information & verification steps for Terraform repos.
#  - Reinforce our PR Quality Gate (fmt/validate/tflint/checkov/plan).
#  - Help reviewers find the plan artifact quickly.
###############################################################
-->

## 🎯 Summary
<!-- What does this PR change? Keep it crisp. -->
-

## 🔗 Related Issue / Ticket
<!-- e.g., Closes #123 or JIRA: WEB-123 -->
-

## 🧩 Scope / Modules touched
<!-- High-level areas (root, modules/*, bootstrap, CI) -->
-

## ✅ Developer Checklist (run locally before pushing)
<!-- These mirror the PR Quality Gate to maximize green PRs. -->
- [ ] `terraform fmt -recursive` is clean
- [ ] `terraform validate` passes
- [ ] `tflint --init && tflint -f compact` passes
- [ ] `checkov -d . --framework terraform` passes (or findings documented below)
- [ ] I reviewed the plan output locally (optional but recommended)

## 🛡️ Security / Compliance Notes
<!-- List notable Checkov findings and rationales, if any. -->
-

## 📦 CI Artifacts (Plan)
<!--
After CI runs, attach the artifact link:
  - For PRs: Actions → this workflow run → Artifacts → tfplan-pr-<PR_NUMBER>
-->
**Plan artifact:** _attach link here after CI finishes_

## 🧪 Test Evidence (optional)
<!-- Validation steps, manual tests, screenshots if relevant -->
-

## 👀 Reviewers / Ownership
<!-- CODEOWNERS will be requested automatically; add extra reviewers if needed. -->
Requested: @bond50

## ⚠️ Risk / Rollout
- **Risk level:** Low / Medium / High
- **Rollback plan:** `terraform apply` previous plan (if saved) or revert commit; consider state backups/versioning.
- **Post-merge:** Back-merge `main → develop` when applicable.

---

### 🔍 Notes for Reviewers (quick cues)
- Confirm `terraform validate` and `tflint` signal sane structural changes.
- Skim **Checkov** output; any “high” risk items must be justified or fixed.
- At least one reviewer should open the **plan** and verify drift/changes match the PR description.
- Check tags and naming (Project/Usage), IAM scoping, and resource lifecycles (create-before-destroy where needed).
