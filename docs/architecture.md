# Knife Architecture

> Source of truth: [`ai-track-docs/architecture.mmd`](../ai-track-docs/architecture.mmd)
> Render locally: `npx --yes @mermaid-js/mermaid-cli mmdc -i ai-track-docs/architecture.mmd -o /tmp/knife-arch.svg`

## Node → File Path Map

| Conceptual Node | Class / Module | File Path |
|---|---|---|
| CLI entry point | `bin/knife` | `bin/knife` |
| Application bootstrap | `Chef::Application::Knife` | `lib/chef/application/knife.rb` |
| Base command class | `Chef::Knife` | `lib/chef/knife.rb` |
| Command loader | `Chef::Knife::SubcommandLoader` | `lib/chef/knife/core/subcommand_loader.rb` |
| Hashed loader | `Chef::Knife::HashedCommandLoader` | `lib/chef/knife/core/hashed_command_loader.rb` |
| UI output layer | `Chef::Knife::UI` | `lib/chef/knife/core/ui.rb` |
| Text formatter | `Chef::Knife::TextFormatter` | `lib/chef/knife/core/text_formatter.rb` |
| Bootstrap command | `Chef::Knife::Bootstrap` | `lib/chef/knife/bootstrap.rb` |
| Bootstrap context (Linux) | `Chef::Knife::BootstrapContext` | `lib/chef/knife/core/bootstrap_context.rb` |
| Bootstrap context (Windows) | `Chef::Knife::WindowsBootstrapContext` | `lib/chef/knife/core/windows_bootstrap_context.rb` |
| Status command | `Chef::Knife::Status` | `lib/chef/knife/status.rb` |
| Status presenter | `Chef::Knife::StatusPresenter` | `lib/chef/knife/core/status_presenter.rb` |
| Cookbook upload | `Chef::Knife::CookbookUpload` | `lib/chef/knife/cookbook_upload.rb` |
| ChefFS sync layer | `Chef::ChefFS::Knife` | `lib/chef/chef_fs/knife.rb` |
| Node editor | `Chef::Knife::NodeEditor` | `lib/chef/knife/core/node_editor.rb` |
| Node presenter | `Chef::Knife::NodePresenter` | `lib/chef/knife/core/node_presenter.rb` |
| Licensing handler | `Chef::Utils::LicensingHandler` | `lib/chef/utils/licensing_handler.rb` |

## Runtime Dependencies

| Gem | Version | Role |
|---|---|---|
| `train-core` | `~> 3.13` | Transport abstraction (SSH/WinRM/local) |
| `train-winrm` | `>= 0.2.17` | Windows remote management transport |
| `net-ssh` | `>= 5.1` | SSH protocol implementation |
| `net-ssh-multi` | `~> 1.2` | Parallel SSH (knife ssh) |
| `mixlib-cli` | `~> 2.1` | Option parsing for subcommands |
| `ffi-yajl` | `~> 2.2` | Fast JSON parsing |
| `erubis` | `~> 2.7` | ERB template rendering (bootstrap scripts) |

## Data Flows

### Flow A — `knife bootstrap` (provision a new node)

```
bin/knife
  → Chef::Application::Knife         (lib/chef/application/knife.rb)
  → Chef::Knife::Bootstrap            (lib/chef/knife/bootstrap.rb)
  → Chef::Knife::BootstrapContext     (lib/chef/knife/core/bootstrap_context.rb)
    renders install script via erubis
  → train-core                        (gem: train-core)
  → net-ssh / train-winrm             (gem: net-ssh / train-winrm)
  → Remote Node (SSH port 22 / WinRM port 5985-5986)
    executes install script, registers with Chef Server
```

### Flow B — `knife status` (query node health)

```
bin/knife
  → Chef::Application::Knife         (lib/chef/application/knife.rb)
  → Chef::Knife::Status               (lib/chef/knife/status.rb)
    builds search query + options via build_query / build_search_opts
  → Chef Infra Server REST API        (HTTPS /search/node)
  → response JSON parsed by ffi-yajl
  → Chef::Knife::StatusPresenter      (lib/chef/knife/core/status_presenter.rb)
  → Chef::Knife::UI                   (lib/chef/knife/core/ui.rb)
    prints formatted table to stdout
```

### Flow C — `knife cookbook upload` (sync local cookbook to server)

```
bin/knife
  → Chef::Application::Knife         (lib/chef/application/knife.rb)
  → Chef::Knife::CookbookUpload       (lib/chef/knife/cookbook_upload.rb)
  → Chef::ChefFS::Knife               (lib/chef/chef_fs/knife.rb)
    diffs local cookbook tree vs server version
  → Chef Infra Server REST API        (PUT /cookbooks/<name>/<version>)
    uploads tarball of cookbook files
```

## Test Suite Layout

| Directory | Scope | Count (approx) |
|---|---|---|
| `spec/unit/` | Pure unit tests, all deps mocked | ~2500 examples |
| `spec/functional/` | Light integration, real filesystem | ~50 examples |
| `spec/integration/` | Requires live Chef Server | Skipped in CI |

Run unit tests:
```bash
bundle exec rspec spec/unit/
```
