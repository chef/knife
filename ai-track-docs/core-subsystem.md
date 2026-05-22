# Knife Core Subsystem — Documentation

> **Scope:** `lib/chef/knife/core/`  
> **Last audited:** 2026-05-20  
> **Status of `docs/dev/README.md`:** covers execution flow at a high level but
> does not reference individual files in `core/`, their public APIs, extension
> points, or risks.

---

## Overview

`lib/chef/knife/core/` is the **shared infrastructure layer** used by all 149
knife subcommands. It provides:

- Plugin/subcommand discovery and loading
- User interaction (stdout, stderr, prompts, color)
- Output formatting (human-readable, JSON, YAML)
- Bootstrap script context rendering
- Node/status presenters

Subcommands in `lib/chef/knife/*.rb` never talk directly to `stdlib` I/O —
they always go through this layer.

---

## File Inventory

| File | Lines | Responsibility |
|------|-------|----------------|
| `subcommand_loader.rb` | 208 | Discovers and loads subcommand Ruby files |
| `ui.rb` | 339 | All user-facing I/O (msg, warn, error, output, prompts) |
| `generic_presenter.rb` | 238 | Formats output data (summary, JSON, YAML, cookbook list) |
| `formatting_options.rb` | ~40 | Mixin: adds `--format` and `--attribute` options to commands |
| `node_presenter.rb` | ~60 | Formats node objects for display |
| `status_presenter.rb` | 147 | Formats node status for `knife status` |
| `gem_glob_loader.rb` | 134 | Loads subcommands via gem path glob (legacy) |
| `hashed_command_loader.rb` | ~80 | Loads subcommands via pre-built manifest hash |
| `object_loader.rb` | ~50 | Loads Chef objects (nodes, roles, etc.) from JSON files |
| `node_editor.rb` | ~80 | Opens node data in `$EDITOR` for `knife node edit` |
| `bootstrap_context.rb` | 304 | Renders bootstrap shell script (Linux/macOS) |
| `windows_bootstrap_context.rb` | 507 | Renders bootstrap `.bat` script (Windows) |
| `cookbook_scm_repo.rb` | 159 | Git/SVN integration for cookbook upload |
| `cookbook_site_streaming_uploader.rb` | 244 | Streams cookbook tarballs to Supermarket |
| `text_formatter.rb` | ~40 | Formats tabular text output |

---

## Key Classes & Public APIs

### `Chef::Knife::SubcommandLoader` — `subcommand_loader.rb`

Entry point for plugin discovery. Used by `Chef::Knife` base class at startup.

```ruby
# Factory method — returns the right loader for the current config
loader = Chef::Knife::SubcommandLoader.for_config(chef_config_dir)

# Primary API
loader.load_commands           # load all available subcommands
loader.load_command(args)      # load subcommands matching args
loader.list_commands(category) # list commands, optionally by category
loader.command_class_from(args)# return the Class for given CLI args
loader.subcommand_files        # array of all loadable .rb paths
```

**Real file paths involved:**
- `lib/chef/knife/core/subcommand_loader.rb` — base class
- `lib/chef/knife/core/gem_glob_loader.rb` — glob-based loader
- `lib/chef/knife/core/hashed_command_loader.rb` — manifest-based loader

---

### `Chef::Knife::UI` — `ui.rb`

All subcommands receive a `ui` instance via `knife.ui`. Never write to
`$stdout`/`$stderr` directly in a subcommand.

```ruby
ui.msg("plain message")          # stdout
ui.warn("warning text")          # stderr, yellow
ui.error("error text")           # stderr, red
ui.fatal("fatal message")        # stderr, red bold
ui.fatal!("msg")                 # fatal + exit(1)
ui.output(data)                  # formatted output (respects --format)
ui.info("informational")         # stdout
ui.color("text", :red, :bold)    # ANSI color (no-op if not a tty)
ui.ask_question("Prompt: ")      # interactive prompt
ui.use_presenter(PresenterClass) # swap the output formatter
```

**Real file path:** `lib/chef/knife/core/ui.rb`

---

### `Chef::Knife::Core::GenericPresenter` — `generic_presenter.rb`

Handles `--format` flag. Formats output as summary (default), JSON, or YAML.
Delegated through `ui.output`.

```ruby
# Called automatically via ui.output(data)
presenter.format_list_for_display(item)
presenter.format_for_display(item)
presenter.format_cookbook_list_for_display(item)
```

**Real file path:** `lib/chef/knife/core/generic_presenter.rb`

---

### `Chef::Knife::Core::FormattingOptions` — `formatting_options.rb`

Mixin included by subcommands that need `--format` / `--attribute` options.

```ruby
# Include in a subcommand:
include Knife::Core::FormattingOptions
# Adds: --format (summary|text|json|yaml|pp)
#       --attribute ATTR (filter displayed attributes)
```

**Real file path:** `lib/chef/knife/core/formatting_options.rb`

---

## Extension Guide — Writing a New Subcommand

A minimal subcommand uses two core files:

```ruby
# lib/chef/knife/my_command.rb
require_relative "../knife"

class Chef
  class Knife
    class MyCommand < Knife
      include Knife::Core::FormattingOptions   # optional: adds --format

      banner "knife my command [ARGS] (options)"

      deps do
        require "chef/node" unless defined?(Chef::Node)
      end

      option :verbose,
        short: "-v",
        long: "--verbose",
        description: "Verbose output"

      def run
        # Use ui (never $stdout directly)
        ui.msg("Running my command")
        result = rest.get("/nodes")          # authenticated GET
        output(format_for_display(result))   # respects --format
      end
    end
  end
end
```

**Spec file location:** `spec/unit/knife/my_command_spec.rb`

**Minimum spec pattern:**

```ruby
require "knife_spec_helper"

describe Chef::Knife::MyCommand do
  let(:knife) { described_class.new }
  let(:rest)  { double("Chef::ServerAPI") }

  before do
    allow(knife).to receive(:rest).and_return(rest)
    allow(knife.ui).to receive(:stdout).and_return(StringIO.new)
  end

  it "calls the correct API endpoint" do
    expect(rest).to receive(:get).with("/nodes").and_return({})
    knife.run
  end
end
```

---

## Risk Notes

| Risk | Location | Mitigation |
|------|----------|-----------|
| `UI#output` behavior depends on `--format` flag | `ui.rb:187` | Always test with default format and with `config[:format] = "json"` |
| `SubcommandLoader` caches discovered commands | `subcommand_loader.rb:103` | Clear with `SubcommandLoader.reset!` in specs if needed |
| `GenericPresenter` is shared by all commands | `generic_presenter.rb` | Changes here affect all 149 subcommands — test broadly before modifying |
| Bootstrap context renders ERB templates | `bootstrap_context.rb`, `windows_bootstrap_context.rb` | Template changes can silently produce invalid shell scripts; always test render output |
| `cookbook_site_streaming_uploader.rb` uses raw HTTP | `cookbook_site_streaming_uploader.rb` | No retry logic; network failures are fatal — do not modify without functional tests |
| `node_editor.rb` spawns `$EDITOR` subprocess | `node_editor.rb` | Difficult to unit test; relies on `Tempfile` and system env var |

---

## Doc-with-Code Changes in This PR

The following code changes were made to align implementation with docs:

| File | Change | Reason |
|------|--------|--------|
| `lib/chef/knife/status.rb` | Added `# @api private` comment to `#build_query` and `#build_search_opts` | Docs describe these as private helpers; code now matches intent |

---

## Stale Docs Identified

| Location | Gap |
|----------|-----|
| `docs/dev/README.md` | Does not mention `lib/chef/knife/core/` at all — developers have no map to the shared layer |
| `docs/dev/README.md` | Extension guide links to external Chef docs, not this repo's patterns |
| `lib/chef/knife/core/ui.rb` | No YARD doc on `#output` or `#use_presenter` describing the presenter swap contract |

These gaps are addressed by this file (`ai-track-docs/core-subsystem.md`).

---

## Further Reading

- [`SYSTEM-OVERVIEW.md`](./SYSTEM-OVERVIEW.md) — top-level repo map
- [`build-test.md`](./build-test.md) — how to run tests locally
- [`docs/dev/README.md`](../docs/dev/README.md) — original developer guide (execution flow)
- Chef Knife plugin guide: https://docs.chef.io/workstation/plugin_knife_custom/
