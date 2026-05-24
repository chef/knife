# Knife – System Overview

> **Version**: 19.0.116  
> **License**: Apache-2.0  
> **Required Ruby**: ≥ 3.1

## Purpose

`knife` is the command-line interface for **Chef Infra**. It bridges a local Chef
repository with a remote Chef Infra Server, enabling operators and developers to
manage nodes, upload/download cookbooks, interact with the Chef API, bootstrap
remote machines, and run ad-hoc queries against server data.

## High-Level Architecture

```
Developer workstation
  └─ bin/knife  ──► Chef::Application::Knife   (lib/chef/application/knife.rb)
                         │
                         ▼
                   Chef::Knife  (lib/chef/knife.rb)  ◄── plugin autoloader
                         │
              ┌──────────┴──────────────────────────┐
              │  Subcommand classes                  │
              │  lib/chef/knife/<command>.rb         │
              │  (e.g. bootstrap, node list, …)      │
              └──────────────────────────────────────┘
                         │
                    train-core / Net::HTTP
                         │
                    Chef Infra Server  (REST API)
```

## Key Subsystems

| Subsystem | Path | Responsibility |
|-----------|------|----------------|
| Application entry point | `lib/chef/application/knife.rb` | Argument parsing, plugin loading |
| Core knife class | `lib/chef/knife.rb` | Base class for all subcommands |
| Subcommands | `lib/chef/knife/*.rb` | Individual CLI actions (149 files) |
| Core utilities | `lib/chef/knife/core/` | UI, formatters, bootstrap helpers |
| Chef-FS | `lib/chef/chef_fs/` | Local ↔ server file-system abstraction |
| Bootstrap | `lib/chef/knife/bootstrap/` | Node provisioning templates & logic |

### Shared Helpers (added in Walk/Run track)

| Helper | File | Used by |
|--------|------|---------|
| `RetryWithBackoff` | `lib/chef/knife/core/retry_with_backoff.rb` | `cookbook_list.rb`, `supermarket_show.rb` |
| `NodeRunListBase` | `lib/chef/knife/node_run_list_base.rb` | `node_run_list_add.rb`, `node_run_list_remove.rb`, `node_run_list_set.rb` |

See [`ai-track-docs/core-subsystem.md`](./core-subsystem.md) for full API reference and risk notes.

## Entry Points (concrete paths)

### 1. `bin/knife`
The executable. Adds `lib/` to the load path and calls
`Chef::Application::Knife.new.run`.

### 2. `lib/chef/application/knife.rb`
Mixes in `Chef::Application`. Responsibilities:
- Loads `~/.chef/credentials` and `knife.rb` via `WorkstationConfigLoader`
- Discovers and loads subcommand plugins (via `SubcommandLoader`)
- Delegates execution to the matched subcommand's `#run`

### 3. `lib/chef/knife.rb`
The base class every subcommand inherits from. Provides:
- `option` DSL (wraps `mixlib-cli`)
- `ui` helper → `lib/chef/knife/core/ui.rb`
- `rest` / `server_api` — authenticated HTTP client to Chef Infra Server
- `#run_with_pretty_exceptions` — top-level error wrapper

### 4. `lib/chef/knife/<command>.rb`
One file per subcommand. Each defines a class under `Chef::Knife::` that
overrides `#run`. As of v19.0.116 there are **149 subcommand files**.

> **How to verify entry-point flow:**  
> `grep -n "def run" lib/chef/application/knife.rb` — shows where dispatch happens.  
> `grep -n "def run_with_pretty_exceptions" lib/chef/knife.rb` — shows the wrapper.

## Technology Stack

| Layer | Technology |
|-------|-----------|
| Language | Ruby 3.1+ |
| Test framework | RSpec |
| Build | Rake + Bundler |
| Packaging | RubyGems + Habitat |
| CI/CD | Expeditor |
| Code quality | SonarQube, Cookstyle |
| Remote transport | train-core, train-winrm |

## Repository Layout (top-level)

```
knife/
├── bin/            # knife executable
├── lib/            # all library code
├── spec/           # RSpec test suite (unit / functional / integration)
├── habitat/        # Habitat packaging
├── docs/           # Developer documentation
├── ai-track-docs/  # AI-assisted development tracking (this folder)
└── .copilot-track/ # Copilot crawl artifacts & prompt records
```

## Release Process

1. Merges to `main` trigger **Expeditor** pipelines.
2. Expeditor bumps `VERSION`, updates `CHANGELOG.md`, builds a Habitat package,
   and pushes a new gem to RubyGems.
3. Habitat packages flow through channels: `base-2025-current` → `base-2025` → `stable`.

## Test Approach

| Suite | Path | What it covers |
|-------|------|----------------|
| Unit | `spec/unit/` | One spec file per class; external calls mocked; 93 spec files |
| Functional | `spec/functional/` | Real filesystem & config; no network |
| Integration | `spec/integration/` | Live Chef server; not run in normal CI |

**Coverage gate: ≥ 80 %** (enforced in CI via SimpleCov).  
Run all suites: `bundle exec rake spec`

> **Note:** SimpleCov is **not** currently wired into the spec helpers
> (verified: `grep -r "SimpleCov" spec/` returns nothing). Coverage is enforced
> by the CI pipeline rather than a local report. Running `bundle exec rake spec`
> locally will **not** print a coverage percentage without adding SimpleCov manually.

---

## Low-Risk Modules for First Modifications

Three subcommands that are safe to modify because they are small, isolated,
and well-tested:

| # | File | Lines | Spec | Why safe |
|---|------|-------|------|----------|
| 1 | `lib/chef/knife/cookbook_list.rb` | 47 | `spec/unit/knife/cookbook_list_spec.rb` (88 lines) | GET only; no writes; URL-building logic easy to extend |
| 2 | `lib/chef/knife/environment_show.rb` | 47 | `spec/unit/knife/environment_show_spec.rb` (52 lines) | Two-line `#run`; GET only; `Chef::Environment.load` fully mocked |
| 3 | `lib/chef/knife/node_show.rb` | 63 | `spec/unit/knife/node_show_spec.rb` (65 lines) | GET only; display-only options; `Chef::Node.load` fully mocked |

### ⭐ Recommended: `lib/chef/knife/cookbook_list.rb`

**What it does:** builds a Chef Server API endpoint URL (optionally scoped to
an environment), makes a single read-only GET request, and formats the
cookbook list for display.

**Core logic (the full `#run`):**

```ruby
def run
  env          = config[:environment]
  num_versions = config[:all_versions] ? "num_versions=all" : "num_versions=1"
  api_endpoint = env ? "/environments/#{env}/cookbooks?#{num_versions}" : "/cookbooks?#{num_versions}"
  cookbook_versions = rest.get(api_endpoint)
  ui.output(format_cookbook_list_for_display(cookbook_versions))
end
```

**Why it is the lowest-risk entry point:**

1. **Read-only** — single GET; no POST/PUT/DELETE; no server state changed.
2. **47 lines, one method** — entire logic fits in `#run`; no inheritance
   complexity beyond base `Knife`.
3. **Best spec coverage of all candidates** — 88 spec lines mock `rest.get`
   and assert output; adding new test cases is straightforward.
4. **No downstream dependents** — nothing in `lib/` inherits from or calls
   `CookbookList` (verified: `grep -r "CookbookList" lib/`).
5. **Easy additive changes** — e.g. adding `--filter-name PATTERN` to grep
   cookbook names, or improving the banner text, are fully self-contained.

**Safe changes to make here (concrete examples):**

| Change | What to touch | Risk |
|--------|--------------|------|
| Add `--filter-name PATTERN` option | Add `option` block + filter `cookbook_versions` hash by key | Zero — additive only |
| Improve the banner/help text | Change the `banner` string | Zero — display only |
| Add `--num-versions N` option | Replace hard-coded `"num_versions=1"` with config value | Low — URL string change only |
| Improve error when server unreachable | Wrap `rest.get` in `rescue Net::HTTPServerException` | Low — isolated rescue block |
| Rename `--all` to be clearer | Update `option` long flag + description string | Low — option alias only |

**What NOT to change here:**
- `format_cookbook_list_for_display` — lives in `lib/chef/knife/core/generic_presenter.rb`; changing it affects every command that displays cookbooks
- `rest.get` transport — lives in base `Chef::Knife`; not this file's concern

**Assumptions & how to verify:**

| Assumption | Verify with |
|------------|-------------|
| Spec file exists | `ls spec/unit/knife/cookbook_list_spec.rb` |
| No class inherits from `CookbookList` | `grep -r "CookbookList" lib/` |
| No other command delegates to it | `grep -r "cookbook_list" lib/` |
| `format_cookbook_list_for_display` lives in base class | `grep -rn "def format_cookbook_list_for_display" lib/` |

---

## Further Reading

- [`build-test.md`](./build-test.md) – how to build, test, and lint locally
- [`architecture.mmd`](./architecture.mmd) – Mermaid component diagram
- [`docs/dev/README.md`](../docs/dev/README.md) – full developer setup guide
