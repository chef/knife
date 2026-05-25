# Run Ex10 — CI/CD Baseline

**Level**: Run | **Exercise**: 10 | **Branch**: `learn/run/nikhil-ex10-ci-baseline`

## Goal

Reduce CI delivery friction and runner-minute waste through two targeted reliability
improvements: bundler gem caching and explicit job timeouts.

---

## Baseline Audit

### Improvement A — Bundler caching

Five workflows had `bundler-cache: false`, causing a full `bundle install` (~150 gems)
on every single CI run. This is slow and fragile (transient rubygems.org failures).

| Workflow | Job(s) | bundle install (before) |
|----------|--------|------------------------|
| `unit_specs.yml` | `unit` (6-OS matrix) | ~50s × 6 = ~5 min total |
| `lint.yml` | `cookstyle` | ~50s per run |
| `feature-flag-matrix.yml` | `flag-matrix` (×2) | ~50s × 2 |
| `coverage-advisory.yml` | `coverage-summary` | ~50s per run |
| `gem_tests.yml` | `knife-windows` | ~50s per run |

Evidence from CI logs (PR #155–#157):

```
# cookstyle job total: 59s
# of which bundle install (bundle install phase): ~40-50s
Installing faraday-http-cache 2.7.0 ... (40+ lines)
Bundle complete! 22 Gemfile dependencies, 164 gems now installed.
```

With `bundler-cache: true` (warm cache), `setup-ruby` restores the gem cache
in **~5-10s** — a ~40-45s reduction per job.

### Improvement B — Job timeouts

Seven jobs had no `timeout-minutes`, allowing runaway processes to consume runner
minutes until GitHub's 6-hour global limit.

| Workflow | Job | timeout-minutes (before → after) |
|----------|-----|----------------------------------|
| `lint.yml` | cookstyle | none → **20** |
| `lint.yml` | spellcheck | none → **10** |
| `lint.yml` | linelint | none → **5** |
| `feature-flag-matrix.yml` | flag-matrix | none → **20** |
| `static-analysis.yml` | cookstyle (chefstyle) | none → **15** |
| `static-analysis.yml` | rubocop-core | none → **10** |
| `coverage-advisory.yml` | coverage-summary | none → **30** |

---

## Changes Applied

### `unit_specs.yml`
- `unit` job: `bundler-cache: false` → `true`; removed redundant `run: bundle install`
- `unit-rocky` job (rbenv-based, cannot use bundler-cache): `bundle install` → `bundle install --retry=3 --jobs=4`

### `lint.yml`
- `cookstyle`: `bundler-cache: false` → `true`; removed `bundle install` from run block; added `timeout-minutes: 20`
- `spellcheck`: added `timeout-minutes: 10`
- `linelint`: added `timeout-minutes: 5`

### `feature-flag-matrix.yml`
- `bundler-cache: false` → `true`; removed `run: bundle install`; added `timeout-minutes: 20`

### `coverage-advisory.yml`
- `bundler-cache: false` → `true`; removed `run: bundle install`; added `timeout-minutes: 30`

### `gem_tests.yml`
- `bundler-cache: false` → `true`; removed explicit `bundle install --jobs=3 --retry=3` (now managed by `setup-ruby`)

### `static-analysis.yml`
- Already had `bundler-cache: true` ✅
- Added `timeout-minutes: 15` (cookstyle) and `timeout-minutes: 10` (rubocop-core)

---

## Before/After Summary

| Metric | Before | After | Improvement |
|--------|--------|-------|-------------|
| `bundle install` time (warm) | ~50s/job | ~5-10s/job | ~40-45s saved |
| Jobs with unbounded runtime | 7 | 0 | All bounded |
| Transient install failure surface | High | Low (cached) | Risk reduced |
| `bundle install` without `--retry` | 4 locations | 0 (rbenv: +retry) | More resilient |

---

## How to Validate

```bash
# 1. Push branch and monitor CI — warm cache hit shows:
#    "Bundled gems are up to date!" with no gem install lines

# 2. Verify timeout boundaries are enforced — check job-level timeout in GitHub UI

# 3. Lint job should complete cookstyle in <20 min (actual: ~60s)
```

---

## Risk

**Low.** All changes are configuration-only:
- `bundler-cache: true` is a flag supported by `ruby/setup-ruby` — documented, widely used
- Removing redundant `bundle install` has no effect when setup-ruby manages it
- `timeout-minutes` only activates if a job exceeds the limit — no impact on normal runs

---

## Rollback

```bash
git revert HEAD
```

Each change is a single-line edit or step removal. Reverting is atomic and immediate.
Individual file revert:

```bash
git checkout HEAD~1 -- .github/workflows/unit_specs.yml
git checkout HEAD~1 -- .github/workflows/lint.yml
# etc.
```
