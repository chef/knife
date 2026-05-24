# Onboarding Prompt — Walk Track

> **How to use**: Paste this entire file into Copilot Chat at the start of a
> new session to orient Copilot to the repo and the Walk track conventions.

---

## Repo at a Glance

**Repo**: `chef/knife` — Ruby CLI gem that provides an interface between a
local Chef repository and the Chef Infra Server.

Key directories:
```
lib/chef/knife/          # Individual knife subcommands (e.g. node_show.rb)
lib/chef/knife/core/     # Shared presenters, formatters, helpers
lib/chef/knife.rb        # Base class — all subcommands inherit this
lib/chef/application/knife.rb  # Entry point (bin/knife calls this)
spec/unit/knife/         # RSpec unit tests, one file per command
spec/functional/         # Functional tests
ai-track-docs/           # Track documentation and exercise artifacts
docs/                    # Architecture, onboarding, developer guide
.github/workflows/       # CI: lint, DCO, specs, coverage-advisory, mermaid-lint
```

Tech stack: Ruby 3.1+, RSpec, SimpleCov, Rake, Bundler.

---

## Walk Track Rules

1. **Plan first** — before touching any code, produce a written plan:
   - Which files change and why
   - Test strategy
   - Risk and rollback path

2. **Evidence-backed PRs** — every PR must include test output and coverage %

3. **Chained branches** — each exercise branches from the previous:
   ```
   learn/walk/nikhil-ex1-architecture-map
    └── learn/walk/nikhil-ex2-coverage-surfacing
         └── learn/walk/nikhil-ex3-show-refactor
              └── learn/walk/nikhil-ex<N>-<slug>
   ```
   PR base = previous exercise branch.

4. **Single commit per exercise** — Copilot-authored, DCO-signed:
   ```bash
   GIT_AUTHOR_NAME="Copilot" \
   GIT_AUTHOR_EMAIL="223556219+Copilot@users.noreply.github.com" \
   git commit --signoff \
     --trailer "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>" \
     -m "Walk ExN: <description>"
   ```

5. **Labels**: `ai-assisted` + `[DO NOT MERGE]` in title.

---

## PR Template

```
Title: GHCP -- Walk: <ex#> <name>

Summary
- What changed and why
- Plan: <inline summary>
- Files/paths touched

Evidence
- Tests: <N> examples, <N> failures
- Line coverage: <X>% (<covered> / <total>)
- Command: COVERAGE=true bundle exec rake spec

Risk & Rollback
- Risk: low/medium/high
- Rollback: revert <commit SHA>

Review Focus
- Key areas for reviewer attention
- Verification steps the reviewer can run

Track
- Level: Walk
- Exercise: <ex#>
```

---

## Key Commands

```bash
# Install dependencies
bundle install

# Run all tests
bundle exec rake spec

# Run single spec file
bundle exec rspec spec/unit/knife/<command>_spec.rb

# Run tests with coverage
COVERAGE=true bundle exec rake spec

# Check spelling (same check as CI)
npx cspell "**/*.md" --no-progress
```

---

## CI Checks

| Workflow | What it checks |
|----------|---------------|
| `lint.yml` | cspell spellcheck on all `.md` files |
| `dco.yml` | DCO sign-off on every commit |
| `unit_specs.yml` | Full RSpec suite |
| `coverage-advisory.yml` | SimpleCov line/branch % (advisory, non-blocking) |
| `mermaid-lint.yml` | Validates `.mmd` diagram files render |

---

## Further Reading

- [CONTRIBUTING.md](../CONTRIBUTING.md) — branching, PR format, DCO, Walk workflow
- [docs/dev/README.md](dev/README.md) — execution flow, bootstrap, plugins
- [docs/architecture.md](architecture.md) — node→path map and data flows
- [ai-track-docs/SYSTEM-OVERVIEW.md](../ai-track-docs/SYSTEM-OVERVIEW.md) — system overview
- [ai-track-docs/coverage.md](../ai-track-docs/coverage.md) — coverage baseline and PR snippet
