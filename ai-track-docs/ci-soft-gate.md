# Ex10 — CI Soft Gating: Coverage Advisory

## Goal
Surface test coverage as evidence in CI without blocking merges.

## What Was Added

### `.github/workflows/coverage-advisory.yml`
A new non-blocking workflow job (`continue-on-error: true`) that:
1. Runs the full RSpec suite with `COVERAGE=true bundle exec rake spec`
2. Parses SimpleCov's stdout (`Line Coverage: XX.XX% (N / M)`)
3. Posts a markdown table to the GitHub job summary (`$GITHUB_STEP_SUMMARY`)

### `spec/support/coverage.rb`
Loads SimpleCov when `COVERAGE=true` is set:
- Enables line + branch coverage
- Filters `spec/` and `vendor/` from results
- Tracks all `lib/**/*.rb` files

### `spec/knife_spec_helper.rb`
Added `require_relative "support/coverage"` before application requires — ensures SimpleCov instruments all loaded files.

## Local Verification

```bash
COVERAGE=true bundle exec rake spec 2>&1 | grep "Coverage"
# => Line Coverage: 47.26% (3558 / 7528)
# => Branch Coverage: 21.76% (571 / 2624)
```

## CI Job Summary Output (example)

| Metric | Value |
|--------|-------|
| Line coverage   | 47.26% |
| Branch coverage | 21.76% |
| Examples        | 2250 examples, 0 failures |
| Threshold       | 80.0% line coverage (advisory only) |

> This check is **advisory only** — it never blocks a merge.

## Design Decisions

| Decision | Rationale |
|----------|-----------|
| `continue-on-error: true` | Ensures the job never gates a merge |
| Parse stdout vs JSON file | SimpleCov 0.22 doesn't ship `JSONFormatter`; stdout is always written |
| 80% threshold (advisory) | Reasonable target for a CLI gem; surfaced as ⚠️, not a failure |

## Rollback
```bash
git revert HEAD  # removes coverage-advisory.yml and spec/support/coverage.rb
```

---

## Walk Ex10 — CI Soft Gating Enhancement

### Problem with Crawl Ex10

The job summary posts coverage to `$GITHUB_STEP_SUMMARY`, which is only visible inside the GitHub Actions run detail page. PR authors must navigate away from the PR to see coverage evidence — low discoverability.

### Improvement: Inline PR Comment

Added a `Post PR comment (advisory)` step using `actions/github-script@v7`:

- Posts the same coverage table as a **comment on the PR**, visible immediately in the PR thread
- Uses a `<!-- coverage-advisory -->` HTML marker for **idempotency**: re-runs update the existing comment instead of adding duplicates
- Only fires on `pull_request` events (skipped on `push` to `main`)
- Has its own `continue-on-error: true` — a GitHub API failure never blocks CI

### Non-Blocking Guarantee (defense-in-depth)

| Layer | Mechanism |
|-------|-----------|
| Job level | `continue-on-error: true` on the whole job |
| PR comment step | `continue-on-error: true` on the individual step |
| `github-script` error handling | `try/catch` around file read; fallback body posted on error |

### Permissions

Added `pull-requests: write` to the job permissions block. `contents: read` remains for checkout.

### Verification

After the workflow runs on a PR, look for a comment posted by `github-actions[bot]` starting with `<!-- coverage-advisory -->`:

```
## ⚠️ Coverage Advisory (non-blocking)

| Metric | Value |
|--------|-------|
| Line coverage   | 47.26% |
| Branch coverage | 21.76% |
| Examples        | 2264 examples, 0 failures |
| Threshold       | 80.0% line coverage (advisory only) |

> This check is **advisory only** — it never blocks a merge.
```

The same table also appears in the Actions job summary tab.

### Rollback

```bash
git revert HEAD  # restores coverage-advisory.yml to Crawl Ex10 state (job summary only)
```
