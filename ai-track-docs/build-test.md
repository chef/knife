# Build & Test Guide

> **Status:** Placeholder — verify commands against repo tooling before use.

## Prerequisites

- Ruby 3.1+
- Bundler (`gem install bundler`)

## Install Dependencies

```bash
bundle install
```

## Run All Tests

```bash
bundle exec rake spec
```

## Run a Specific Test File

```bash
bundle exec rspec spec/unit/knife/<command>_spec.rb
```

## Run Tests with Verbose Output

```bash
bundle exec rspec spec/unit/knife/<command>_spec.rb --format documentation
```

## Build the Gem Locally

```bash
rake build
```

## Coverage

Tests are run via RSpec. Aim for >80% coverage on any new code.

---

*This file is part of the GHCP Crawl track scaffolding.*
