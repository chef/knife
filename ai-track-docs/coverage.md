# Coverage Baseline

## Walk Ex2 — Build and Test Baseline

### Tooling

| Component | Detail |
|-----------|--------|
| Framework | RSpec |
| Coverage gem | `simplecov 0.22.0` (line + branch) |
| Activation | `COVERAGE=true` env var |
| Config | `spec/support/coverage.rb` — loaded by `spec/knife_spec_helper.rb` |
| CI job | `.github/workflows/coverage-advisory.yml` (advisory, non-blocking) |
| HTML report | `coverage/index.html` (generated locally) |

### Baseline Snapshot

Captured on Walk Ex2 branch (`learn/walk/nikhil-ex2-coverage-surfacing`).

```
Command : COVERAGE=true bundle exec rake spec
Examples: 2253 examples, 0 failures, 7 pending

Line Coverage  : 47.26%  (3556 / 7524)
Branch Coverage: 21.74%   (571 / 2626)
```

> The advisory threshold is 80% line coverage. Current baseline is below threshold —
> this is expected for a mature CLI gem where many paths exercise the live Chef Server.
> The advisory CI job surfaces the number without blocking merges.

### Running Coverage Locally

```bash
# Full suite
COVERAGE=true bundle exec rake spec

# Single file (fast feedback)
COVERAGE=true bundle exec rspec spec/unit/knife/status_spec.rb

# Open HTML report after run
open coverage/index.html
```

### PR Snippet Template

Copy this block into the **Evidence** section of every PR that touches `lib/`:

```
Evidence
- Tests: <N> examples, <N> failures
- Line coverage:   <X>% (<covered> / <total>)
- Branch coverage: <X>%  (<covered> / <total>)
- Command: COVERAGE=true bundle exec rake spec
```

### How the CI Advisory Job Works

`.github/workflows/coverage-advisory.yml`:
1. Runs `COVERAGE=true bundle exec rake spec` and tees output to `/tmp/spec_output.txt`
2. A Ruby inline script parses the SimpleCov terminal output
3. Posts a Markdown table to the GitHub job summary (`$GITHUB_STEP_SUMMARY`)
4. `continue-on-error: true` — the job never fails the PR

### Adding New Coverage

Focus areas with the lowest per-file coverage (visible in `coverage/index.html`):
- `lib/chef/knife/core/` — presenter and loader helpers
- `lib/chef/chef_fs/` — file system abstraction layer
- Bootstrap templates in `lib/chef/knife/bootstrap/`
