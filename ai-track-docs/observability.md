# Run Ex9 — Observability

**Level**: Run | **Exercise**: 9 | **Branch**: `learn/run/nikhil-ex9-observability`

## Goal

Propagate consistent `Chef::Log.trace` instrumentation across `lib/chef/knife/core/`
files that previously had zero operational logging, improving debuggability for
operators running `knife --log-level trace`.

---

## Current State Audit (pre-change)

| File | Log calls | Level(s) |
|------|-----------|----------|
| `cookbook_site_streaming_uploader.rb` | 4 | trace, debug |
| `retry_with_backoff.rb` | 1 | warn |
| `subcommand_loader.rb` | 1 | trace |
| `hashed_command_loader.rb` | 2 | error |
| `object_loader.rb` | **0** | — |
| `gem_glob_loader.rb` | **0** | — |
| `generic_presenter.rb` | 0 | — |
| `node_editor.rb` | 0 | — |
| `text_formatter.rb` | 0 | — |

**Dominant pattern** already established in the folder:

```ruby
Chef::Log.trace("ClassName: action context=#{var.inspect}")
```

---

## Changes Applied

### `lib/chef/knife/core/object_loader.rb` — +7 trace calls

Covers the full file-resolution and parsing pipeline:

```
ObjectLoader: loading Chef::Node from repo_location=nodes components=["web-01.json"]
ObjectLoader: resolved 'web-01.json' as relative path /repo/nodes/web-01.json
ObjectLoader: parsing /repo/nodes/web-01.json
ObjectLoader: using JSON parser for /repo/nodes/web-01.json
```

| Method | Trace content |
|--------|--------------|
| `load_from` | klass + repo_location + components |
| `load_from` | unresolvable file (before `ui.error`) |
| `find_file` | resolved absolute path |
| `find_file` | resolved relative path |
| `object_from_file` | filename being parsed |
| `object_from_file` | JSON parser selected |
| `object_from_file` | Ruby eval selected |

### `lib/chef/knife/core/gem_glob_loader.rb` — +3 trace calls

Covers the subcommand discovery pathway:

```
GemGlobLoader: discovering subcommands via RubyGems
GemGlobLoader: found 142 candidate subcommand file(s) via RubyGems
GemGlobLoader: skipping /path/to/chef-18.x.y/knife/old_cmd.rb (different Chef version)
```

| Method | Trace content |
|--------|--------------|
| `gem_and_builtin_subcommands` | rubygems path chosen |
| `gem_and_builtin_subcommands` (rescue) | dirglob fallback |
| `find_subcommands_via_rubygems` | file count after glob |
| `find_subcommands_via_rubygems` | each skipped file |

### `lib/chef/knife/core/subcommand_loader.rb` — +2 trace calls

Covers manifest generation and write:

```
SubcommandLoader: generating plugin manifest hash
SubcommandLoader: writing plugin manifest to /home/user/.chef/.cache/knife-plugin-manifest.json
```

| Method | Trace content |
|--------|--------------|
| `generate_hash` | manifest generation start |
| `write_hash` | manifest file path |

---

## Total instrumentation added

| File | Before | After | Net |
|------|--------|-------|-----|
| `object_loader.rb` | 0 | 7 | +7 |
| `gem_glob_loader.rb` | 0 | 4 | +4 |
| `subcommand_loader.rb` | 1 | 3 | +2 |
| **Total `core/` folder** | **8** | **22** | **+13** |

---

## How to Validate

### Option 1 — knife CLI (requires configured workstation)

```bash
knife node list --log-level trace 2>&1 | grep -E "ObjectLoader|GemGlob|SubcommandLoader"
```

Expected output (sample):

```
TRACE: GemGlobLoader: discovering subcommands via RubyGems
TRACE: GemGlobLoader: found 142 candidate subcommand file(s) via RubyGems
TRACE: SubcommandLoader: generating plugin manifest hash
TRACE: ObjectLoader: loading Chef::Node from repo_location=nodes ...
```

### Option 2 — RSpec (no server required)

```bash
bundle exec rspec spec/unit/knife/core/ --format progress
# Expected: 0 failures (281 examples)
```

### Option 3 — Targeted spec

```bash
bundle exec rspec spec/unit/knife/core/object_loader_spec.rb -f doc
```

---

## Evidence

Spec run after applying changes (local):

```
281 examples, 0 failures, 1 pending
Finished in 0.69028 seconds (files took 11.32 seconds to load)
```

Pending: 1 pre-existing color test (environment-specific, unrelated to this change).

---

## Risk

**Low.** `Chef::Log.trace` calls are:
- Only active when `--log-level trace` (or `CHEF_LOG_LEVEL=trace`) — silent by default
- Side-effect free — no state mutation
- No performance impact at default log levels

---

## Rollback

```bash
git revert HEAD
```

All changes are additive log calls. Reverting restores the previous zero-logging state
with no functional impact.
