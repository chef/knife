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
| Subcommands | `lib/chef/knife/*.rb` | Individual CLI actions |
| Core utilities | `lib/chef/knife/core/` | UI, formatters, bootstrap helpers |
| Chef-FS | `lib/chef/chef_fs/` | Local ↔ server file-system abstraction |
| Bootstrap | `lib/chef/knife/bootstrap/` | Node provisioning templates & logic |

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

## Further Reading

- [`build-test.md`](./build-test.md) – how to build, test, and lint locally
- [`architecture.mmd`](./architecture.mmd) – Mermaid component diagram
- [`docs/dev/README.md`](../docs/dev/README.md) – full developer setup guide
