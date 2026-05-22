# Extending knife status

This guide explains how to extend or modify the `knife status` command
and the `lib/chef/knife/core/` subsystem.

For the full extension guide including file inventory, public APIs, and
step-by-step instructions for writing a new subcommand, see:

→ **[`ai-track-docs/core-subsystem.md`](core-subsystem.md)**

## Quick Reference

### Add a new field to `knife status` output
1. Add the field name to `PARTIAL_SEARCH_FIELDS` in `lib/chef/knife/status.rb`
2. Update `StatusPresenter` in `lib/chef/knife/core/status_presenter.rb`
3. Add a spec in `spec/unit/knife/status_spec.rb`

### Add a new flag to `knife status`
```ruby
option :my_flag,
  short: "-m",
  long: "--my-flag",
  boolean: true,
  description: "Description of my flag"
```

### Run tests after changes
```bash
bundle exec rspec spec/unit/knife/status_spec.rb --format documentation
```

See `core-subsystem.md` for full details on all core classes and extension patterns.
