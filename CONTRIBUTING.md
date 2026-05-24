# Contributing to a Progress Chef Infra Client Project

Thank you for your interest in contributing to this project! It is part of the larger Progress Chef Infra Client project. Contribution guidelines can be found at [Contributing to Progress Chef Infra Client](https://chef.github.io/chef-oss-practices/projects/chef/contributing/).

## Running Tests

```bash
bundle install
bundle exec rake spec
```

## Running Coverage Locally

Coverage uses [SimpleCov](https://github.com/simplecov-ruby/simplecov) and is enabled via the `COVERAGE` environment variable.

### Full suite with coverage

```bash
COVERAGE=true bundle exec rake spec
```

### Single file with coverage

```bash
COVERAGE=true bundle exec rspec spec/unit/knife/status_spec.rb
```

### Reading the output

After the run completes, SimpleCov prints a summary to the terminal:

```
Line Coverage: 47.26% (3556 / 7524)
Branch Coverage: 21.74% (571 / 2626)
```

An HTML report is also written to `coverage/index.html` — open it in a browser for a
file-by-file breakdown.

### Coverage threshold

The advisory CI threshold is **80% line coverage**.  The check is non-blocking; it
surfaces visibility without preventing merges.  See
`.github/workflows/coverage-advisory.yml` for the full CI job.

### Including coverage in a PR description

When opening a PR, paste the SimpleCov terminal output into the **Evidence** section:

```
Evidence
- Tests: 2253 examples, 0 failures
- Line coverage:   47.26% (3556 / 7524)
- Branch coverage: 21.74%  (571 / 2626)
- Command: COVERAGE=true bundle exec rake spec
```

## AI-Assisted Walk Track

This repo includes a structured AI-assisted learning track.  The notes below
describe the conventions used so contributors can follow the same pattern.

### Plan First

Before touching any code, write a plan:
- List the files to change and why
- Identify the test strategy
- Note any risks or rollback path

Ask Copilot to produce the plan, review it, then approve before implementation
begins.  This produces reviewable evidence that the work was intentional.

### Branching Strategy

Branches are chained so context and artifacts build naturally:

```
main
 └── learn/crawl/nikhil-ex0-bootstrap
      └── learn/crawl/nikhil-ex1-...
           └── ...
                └── learn/walk/nikhil-ex1-architecture-map
                     └── learn/walk/nikhil-ex2-coverage-surfacing
                          └── learn/walk/nikhil-ex<N>-<slug>
```

- Each exercise branches from the previous exercise branch
- PR base = previous exercise branch (keeps diffs focused)
- Branch naming: `learn/walk/<name>-ex<N>-<slug>`

### PR Expectations

Every PR must include these sections:

```
Title: GHCP -- Walk: <ex#> <name>

Summary
- What changed and why
- Plan: <inline summary or link>
- Files/paths touched

Evidence
- Tests/logs/metrics: <commands + output summary>
- Coverage: <percentage or contract evidence>

Risk & Rollback
- Risk: low/medium/high
- Rollback: revert <commit SHA> or toggle <flag>

Review Focus
- Key areas for reviewer attention
- Verification steps the reviewer can run

Track
- Level: Walk
- Exercise: <ex#>
```

### DCO Sign-off

All commits require a Developer Certificate of Origin sign-off:

```bash
git commit --signoff -m "message"
# or
git commit -s -m "message"
```

Builds will fail without it.

### Using Copilot

Recommended workflow per exercise:

1. Paste the exercise block into Copilot Chat
2. Ask: *"Write a plan before touching any code"*
3. Review and approve the plan
4. Ask Copilot to generate diffs file-by-file; review each before accepting
5. Run tests and capture output for the PR Evidence section
6. Commit (single Copilot-authored DCO-signed commit) and open PR

See [docs/onboarding-walk.md](docs/onboarding-walk.md) for a ready-to-paste
Copilot orientation prompt.
