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
