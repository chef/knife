# Static Analysis — Ex14

## Existing Checks

This repository uses [cookstyle](https://github.com/chef/cookstyle) (Chef's RuboCop profile) for static analysis.

### Running Locally

```bash
# Full cookstyle check (what CI runs)
bundle exec cookstyle --chefstyle -c .rubocop.yml

# Scoped rubocop on core/ path (Ex14 additions)
bundle exec rubocop --only Style/StringConcatenation,Style/GuardClause lib/chef/knife/core/

# Auto-correct fixable offenses (dry-run first)
bundle exec rubocop --only Style/StringConcatenation,Style/GuardClause lib/chef/knife/core/ --autocorrect-all --dry-run
```

### CI Workflows

| Workflow | File | What it checks |
|----------|------|----------------|
| Cookstyle | `.github/workflows/static-analysis.yml` (job: `cookstyle`) | Full repo, chefstyle profile |
| RuboCop core | `.github/workflows/static-analysis.yml` (job: `rubocop-core`) | `lib/chef/knife/core/` — StringConcatenation + GuardClause |

## Ex14 Improvements (fixes in `lib/chef/knife/core/`)

A total of **16 offenses** fixed across 5 files:

| File | Cop | Fixes |
|------|-----|-------|
| `core/status_presenter.rb` | `Style/StringConcatenation` | 2 |
| `core/ui.rb` | `Style/GuardClause` | 1 |
| `core/hashed_command_loader.rb` | `Style/GuardClause` | 1 |
| `core/node_editor.rb` | `Style/GuardClause` | 1 |
| `core/bootstrap_context.rb` | `Style/StringConcatenation` | 2 |
| `core/cookbook_site_streaming_uploader.rb` | `Style/StringConcatenation` + `Lint/RedundantStringCoercion` | 8 |
| `core/windows_bootstrap_context.rb` | `Style/StringConcatenation` | 1 |

## Why These Rules

- **`Style/StringConcatenation`** — string `+` allocates a new object; interpolation is idiomatic Ruby and avoids the extra allocation
- **`Style/GuardClause`** — reduces nesting depth, makes the happy path obvious at a glance

## Scope

Rules are enabled only for `lib/chef/knife/core/` in `.rubocop.yml` using the `Include:` key. This avoids surfacing the remaining ~11 findings in other files until each is ready to be cleaned up incrementally.

---

## Walk Ex14 — Frozen String Literals in `lib/chef/knife/core/`

### Rule Added

`Style/FrozenStringLiteralComment` scoped to `lib/chef/knife/core/**/*.rb` in `.rubocop.yml`.

```yaml
Style/FrozenStringLiteralComment:
  Include:
    - "lib/chef/knife/core/**/*.rb"
```

### Why This Rule

`# frozen_string_literal: true` prevents accidental mutation of string literals and can improve performance (fewer allocations). All 15 files in `core/` were missing this pragma.

### Findings: 15 files, 4 with mutable string bugs

Autocorrect added the pragma to all 15 files. Four files had mutable string patterns that would raise `FrozenError` at runtime — all fixed:

| File | Pattern | Fix |
|------|---------|-----|
| `status_presenter.rb:70` | `summarized = ""` | `summarized = +""` |
| `text_formatter.rb:45` | `buffer = ""` | `buffer = +""` |
| `bootstrap_context.rb:93,272,282` | `= ""` / `= <<~CONFIG` | `= +""` / `= +<<~CONFIG` |
| `windows_bootstrap_context.rb:72,406,416` | same | same |

The `+""` (unary plus on string) creates a new mutable empty string — the idiomatic Ruby fix for frozen string literal compatibility.

### Suppressions

**None required.** All 15 files were cleanly fixable.

### CI Gating

`rubocop-core` job in `.github/workflows/static-analysis.yml` now enforces:

```bash
bundle exec rubocop \
  --only Style/StringConcatenation,Style/GuardClause,Style/FrozenStringLiteralComment \
  lib/chef/knife/core/
```

### Test Evidence

```
459 examples, 0 failures, 1 pending
(spec/unit/knife/core/ + status_spec + bootstrap_spec)
```

### Rollback

```bash
git revert HEAD
```
