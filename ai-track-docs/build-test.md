# Build & Test Reference

## Prerequisites

| Requirement | Version |
|-------------|---------|
| Ruby | ≥ 3.1 |
| Bundler | ≥ 2.x |
| Habitat CLI | optional (for `hab` packaging) |

## Setup

```bash
# Install gem dependencies
bundle install
```

## Running Tests

```bash
# Full test suite (preferred)
bundle exec rake spec

# Unit tests only
bundle exec rspec spec/unit/

# Functional tests
bundle exec rspec spec/functional/

# Integration tests
bundle exec rspec spec/integration/

# Single file (fast feedback loop)
bundle exec rspec spec/unit/knife/<command>_spec.rb

# Single file, verbose
bundle exec rspec spec/unit/knife/<command>_spec.rb --format documentation

# With full backtrace
bundle exec rspec spec/unit/knife/<command>_spec.rb --backtrace
```

## Coverage Requirement

> **≥ 80 % test coverage is mandatory.** CI will flag any PR that falls below this threshold.

Coverage is reported after `bundle exec rake spec`. Check the summary line:

```
Coverage report generated … Coverage: 84.7 % (1,234 / 1,457 lines)
```

## Example: Verified Test Run

Running the unit spec for the chosen low-risk module:

```bash
bundle exec rspec spec/unit/knife/cookbook_list_spec.rb --format documentation
```

Expected output:

```
Chef::Knife::CookbookList
  run
    should display the latest version of the cookbooks
    should query cookbooks for the configured environment
    with -w or --with-uri
      should display the cookbook uris
    with -a or --all
      should display all versions of the cookbooks
      should query all versions scoped to the configured environment

5 examples, 0 failures
```

The last example (`should query all versions scoped to the configured environment`)
was added as part of Exercise 2 to cover the previously untested `--all` +
`--environment` combination in `lib/chef/knife/cookbook_list.rb`.

## Building the Gem

```bash
# Build knife-<version>.gem into pkg/
rake build

# Install built gem locally
rake install

# Verify installation
knife --version
```

## Linting

```bash
# Run Cookstyle (Chef-flavoured RuboCop)
bundle exec cookstyle

# Auto-correct safe offenses
bundle exec cookstyle -a
```

## Habitat Packaging

```bash
# Enter Habitat studio (Linux/macOS)
hab studio enter

# Build inside studio
build

# Run Habitat smoke tests
hab pkg exec chef/knife spec
```

## Cleaning Up

```bash
# Remove built gems
rm -rf pkg/

# Reset bundler cache
bundle clean --force

# Full reset (also removes Gemfile.lock)
rm -f Gemfile.lock && bundle install
```

## CI Skip Labels

Apply these labels on a PR to skip specific Expeditor steps:

| Label | Effect |
|-------|--------|
| `Expeditor: Skip All` | Skip all automated actions |
| `Expeditor: Skip Version Bump` | No version increment |
| `Expeditor: Skip Changelog` | No CHANGELOG update |
| `Expeditor: Skip Habitat` | No Habitat package build |

Use **Skip Version Bump** for test-only, documentation, or CI-tooling changes.
