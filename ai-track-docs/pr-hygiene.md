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

---

## Walk Ex11 — PR Template Linter

### Problem with Crawl Ex11

The PR template added in Crawl Ex11 is a UI hint — GitHub pre-fills the PR body but cannot enforce that authors actually fill in the sections. A PR with all six sections left as blank `<!-- placeholder -->` comments passes CI silently.

### Improvement: Advisory Template Linter

`.github/workflows/pr-template-check.yml` adds a non-blocking CI job that:

1. Reads the PR body from `context.payload.pull_request.body`
2. Checks for all six required section headers:
   - `## Summary`
   - `## Evidence`
   - `## Review Focus`
   - `## Verification Steps`
   - `## Risk`
   - `## Rollback`
3. Posts an idempotent PR comment via `actions/github-script@v7`:
   - **✅ all present** — green confirmation comment
   - **⚠️ missing sections** — lists exactly which headers are absent with a link to the template
4. Updates the comment on re-runs (idempotent via `<!-- pr-template-check -->` marker)

### Non-Blocking Guarantee

| Layer | Mechanism |
|-------|-----------|
| Job | `continue-on-error: true` |
| Step | `continue-on-error: true` |

### Triggers

Runs on `pull_request` events: `opened`, `edited`, `synchronize`, `reopened` — so the check re-evaluates every time the PR description is updated.

### Verification

Open or edit a PR. Within ~30 seconds, a comment from `github-actions[bot]` appears in the PR thread:

**All sections present:**
```
✅ PR Template Check (advisory)
All required sections are present: ...
```

**Missing sections:**
```
⚠️ PR Template Check (advisory)
The following required sections appear to be missing:
- `## Evidence`
- `## Review Focus`
```

### Rollback

```bash
git revert HEAD  # removes pr-template-check.yml
```
