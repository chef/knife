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
