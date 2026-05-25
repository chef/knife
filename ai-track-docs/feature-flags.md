# Run Ex13 — Feature Flags / Config

**Level**: Run | **Exercise**: 13 | **Branch**: `learn/run/nikhil-ex13-feature-flags`

## Overview

This document is the authoritative registry of `KNIFE_*` feature flags in this
repository. Flags follow a consistent pattern: ENV variable check, safe default OFF,
structured `Chef::Log.info` output when ON, flag state always logged at `trace`.

---

## Flag Registry

### KNIFE_TIMING

| Field | Value |
|-------|-------|
| **File** | `lib/chef/knife/status.rb:91` |
| **Default** | OFF (unset) |
| **Toggle** | `export KNIFE_TIMING=1` |
| **Behavior (ON)** | Emits `Chef::Log.info("op=knife_status status=ok nodes=N elapsed_ms=M")` after `knife status` search |
| **Behavior (OFF)** | Silent (only `Chef::Log.debug` always logged) |
| **Added** | Run Ex5 |

### KNIFE_DEBUG

| Field | Value |
|-------|-------|
| **File** | `lib/chef/knife.rb:242`, `:451` |
| **Default** | OFF (unset) |
| **Toggle** | `export KNIFE_DEBUG=1` |
| **Behavior (ON)** | Sets log level to `:trace` at startup |
| **Behavior (OFF)** | Default log level from config |
| **Added** | Pre-existing |

### KNIFE_LOADER_SUMMARY *(added Ex13)*

| Field | Value |
|-------|-------|
| **File** | `lib/chef/knife/core/gem_glob_loader.rb` |
| **Default** | OFF (unset) — silent; current behavior preserved exactly |
| **Toggle** | `export KNIFE_LOADER_SUMMARY=1` |
| **Behavior (ON)** | Emits `Chef::Log.info("op=knife_loader_summary source=rubygems subcommands=N skipped=M")` after subcommand discovery; also emits `source=dirglob` summary on RubyGems fallback |
| **Telemetry (always)** | `Chef::Log.trace("GemGlobLoader: KNIFE_LOADER_SUMMARY=...")` — flag state logged regardless |
| **Behavior (OFF)** | No INFO output; trace-only as before |
| **Added** | Run Ex13 |

---

## Flag Helper Pattern

All flags follow this implementation pattern (consistent with `KNIFE_TIMING`):

```ruby
# 1. Telemetry — always log flag state at trace
Chef::Log.trace("ClassName: KNIFE_FLAG_NAME=#{ENV['KNIFE_FLAG_NAME'].inspect}")

# 2. Conditional behavior
if ENV["KNIFE_FLAG_NAME"].to_s != ""
  Chef::Log.info("op=knife_operation_name field1=val1 field2=val2")
end

# 3. Helper predicate (for multi-use)
def flag_name_enabled?
  ENV["KNIFE_FLAG_NAME"].to_s != ""
end
```

**Naming convention**: `KNIFE_<SUBSYSTEM>_<PURPOSE>` in SCREAMING_SNAKE_CASE.

---

## Validation: KNIFE_LOADER_SUMMARY

### OFF (default) — silent

```bash
knife node list --log-level debug 2>&1 | grep knife_loader_summary
# Expected: no output
```

### ON — summary log visible

```bash
KNIFE_LOADER_SUMMARY=1 knife node list --log-level info 2>&1 | grep knife_loader_summary
# Expected:
# INFO: op=knife_loader_summary source=rubygems subcommands=142 skipped=0
```

### Spec evidence (ON/OFF)

```
# RSpec output (17 examples, 0 failures):
KNIFE_LOADER_SUMMARY feature flag
  when KNIFE_LOADER_SUMMARY is unset (default OFF)
    does not emit an INFO summary log              ✅
    still traces the flag state                    ✅
  when KNIFE_LOADER_SUMMARY=1 (ON)
    emits a structured INFO summary with source and subcommand count  ✅
  loader_summary_enabled?
    returns false when KNIFE_LOADER_SUMMARY is unset    ✅
    returns true when KNIFE_LOADER_SUMMARY=1             ✅
    returns true for any non-empty value                 ✅
```

---

## Risk Assessment

| Risk | Mitigation |
|------|-----------|
| INFO log noise for operators who accidentally set the flag | Default is OFF; any non-empty value enables it — easy to unset |
| Structured log format change breaks log parsers | Format matches `op=knife_status` convention already in repo |
| `skipped_count` counter off-by-one | Counter only increments on `from_different_chef_version?` — verified by spec |

---

## Rollback

```bash
# Immediately disable without code change:
unset KNIFE_LOADER_SUMMARY

# Full code rollback:
git revert HEAD
```

The ENV check is purely additive — reverting restores the prior silent behavior.

---

## Adding a New Flag

1. Pick a name: `KNIFE_<SUBSYSTEM>_<PURPOSE>`
2. Add telemetry trace: `Chef::Log.trace("ClassName: KNIFE_FLAG=#{ENV['KNIFE_FLAG'].inspect}")`
3. Add helper predicate: `def flag_enabled? = ENV["KNIFE_FLAG"].to_s != ""`
4. Add conditional INFO log: `Chef::Log.info("op=knife_op ...")`
5. Add ON/OFF RSpec context blocks
6. Register in this document
