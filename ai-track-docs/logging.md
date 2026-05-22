# Ex9 — Structured Logging

## Goal
Improve debuggability by adding consistent structured log output to an
important code path, using consistent fields: `op`, `status`, `elapsed_ms`.

## What Was Added

### Structured Log Line in `knife status`

**File**: `lib/chef/knife/status.rb`  
**Location**: `#run` method, after `q.search` completes

```ruby
Chef::Log.info("op=knife_status status=ok nodes=#{all_nodes.size} elapsed_ms=#{(search_elapsed * 1000).round}")
```

**Fields:**

| Field | Type | Example | Description |
|-------|------|---------|-------------|
| `op` | string | `knife_status` | Operation name — unique per command |
| `status` | string | `ok` | Outcome: `ok` or `error` |
| `nodes` | integer | `42` | Number of nodes returned |
| `elapsed_ms` | integer | `312` | Search duration in milliseconds |

**Example output:**
```
INFO: op=knife_status status=ok nodes=42 elapsed_ms=312
```

---

## How to View Logs

```bash
# Enable INFO logging and run knife status
knife status --log-level info

# Or set via Chef config
export CHEF_LOG_LEVEL=info
knife status

# Filter just the structured log line
knife status --log-level info 2>&1 | grep "op=knife_status"
```

---

## How to Extend to Other Commands

Follow the same pattern in any `#run` method:

```ruby
start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
# ... operation ...
elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start
Chef::Log.info("op=knife_<command> status=ok elapsed_ms=#{(elapsed * 1000).round}")
```

---

## Test Evidence

```
bundle exec rspec spec/unit/knife/status_spec.rb --format documentation

  structured log hook
    logs structured fields after search completes             ✓
    logs 0 nodes in structured format when search returns     ✓

20 examples, 0 failures
```

## Rollback
```bash
git revert HEAD
```
