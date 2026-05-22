# Ex11 — PR Hygiene and Review

## Goal
Improve review clarity by adding a standardized PR template and demonstrating
the Walk PR format with review focus bullets and verification steps.

## What Was Added

### `.github/PULL_REQUEST_TEMPLATE.md`
A GitHub PR template pre-filling all required sections on every new PR:

| Section | Purpose |
|---------|---------|
| Summary | One-line description of the change |
| Evidence | Test output, CI link, screenshots |
| Review Focus | 3–5 bullets pointing reviewers to the riskiest / most important areas |
| Verification Steps | Runnable commands a reviewer can copy-paste locally |
| Risk | Low / Medium / High with rationale |
| Rollback | Exact command(s) to revert |

## Review Focus (this PR)
- **`.github/PULL_REQUEST_TEMPLATE.md`** — New file only; no logic changed. Verify
  sections match the Walk PR template used across Ex0–Ex10.
- **Section ordering** — Summary → Evidence → Review Focus → Verification →
  Risk → Rollback matches the team's established convention.
- **No code paths affected** — Template is UI-only; no Ruby files modified.

## Verification Steps
```bash
# No code change — verify file exists and renders correctly
cat .github/PULL_REQUEST_TEMPLATE.md

# Open a draft PR in GitHub UI to confirm template pre-fills
gh pr create --draft --title "test" --body "" 2>&1 | head -5
```

## Evidence
```
$ cat .github/PULL_REQUEST_TEMPLATE.md | grep "^##"
## Summary
## Evidence
## Review Focus
## Verification Steps
## Risk
## Rollback
```
All six sections present. Template will auto-populate for every new PR.

## Rollback
```bash
git revert HEAD  # removes PULL_REQUEST_TEMPLATE.md
```
