# Ex9 — Observability: Search Duration Log Hook

## Instrumentation Point

**File**: `lib/chef/knife/status.rb`, method `#run`  
**Hook type**: Structured log line (using existing `Chef::Log` / Mixlib::Log)  
**What it measures**: Wall-clock duration of the Chef Server search call + node count returned

### Why this point?

`q.search(:node, ...)` is the only network I/O in `knife status`. Before this change, there was no way to know from logs how long the Chef Server search took or how many nodes were returned. Adding timing here gives operators:
- Visibility into slow Chef Server queries
- A baseline for performance regression detection
- Node count correlation with query filters

---

## Implementation

```ruby
# lib/chef/knife/status.rb  #run
search_start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
q.search(:node, query, build_search_opts) do |node|
  all_nodes << node
end
search_elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - search_start

Chef::Log.info("knife status: search returned #{all_nodes.size} node(s) in #{"%.3f" % search_elapsed}s")
```

`Process.clock_gettime(Process::CLOCK_MONOTONIC)` is used instead of `Time.now` — it is immune to wall-clock adjustments (NTP, DST) and is the correct tool for elapsed-time measurement.

---

## Where to View the Output

### Locally (debug mode)

```bash
knife status --log-level info
```

Expected log line:
```
INFO: Sending query: *:*
INFO: knife status: search returned 42 node(s) in 0.312s
```

### In production / CI

Set `log_level :info` in `knife.rb` (or `client.rb`). The line appears in:
- Terminal stderr when running interactively
- Chef Infra log file (`log_location` in `knife.rb`, default `/var/log/chef/client.log`)
- Any log aggregator (Splunk, Datadog, etc.) ingesting Chef logs

### Grep pattern for alerting

```
knife status: search returned .* in [0-9]+\.[0-9]+s
```

Alert threshold suggestion: `> 5.000s` indicates a slow Chef Server or large node fleet.

---

## Verification Evidence

```
bundle exec rspec spec/unit/knife/status_spec.rb --format documentation

  search duration log hook
    logs node count and elapsed time after search completes
    reports 0 nodes when search returns nothing

20 examples, 0 failures
```

---

## Risk Notes

| Risk | Mitigation |
|------|-----------|
| Log verbosity at `:info` level | Only one line added per `knife status` invocation — negligible noise |
| Monotonic clock availability | `Process::CLOCK_MONOTONIC` is available on all Ruby 2.1+ platforms (Ruby 3.1+ required anyway) |
| Behavior change | No functional change — log line only |

## Rollback

```bash
git revert HEAD  # removes timing instrumentation and tests
```

---

## Walk Ex9 — Observability Enhancement

### Changes

**Improvement 1: Promote `knife status` timing to unconditional `debug` level**

Before (Crawl Ex9): the structured log line only emitted when `KNIFE_TIMING=1` was set.
After (Walk Ex9): always emitted at `Chef::Log.debug` so standard `--log-level debug` works.
`KNIFE_TIMING` still triggers an additional `info`-level line for CI/scripting compatibility.

```ruby
# Always visible at debug level:
Chef::Log.debug("op=knife_status status=ok nodes=N elapsed_ms=T")
# Also at info when KNIFE_TIMING=1:
Chef::Log.info("op=knife_status status=ok nodes=N elapsed_ms=T") if ENV["KNIFE_TIMING"]
```

**Improvement 2: Add load-time timing to `knife node show`**

`lib/chef/knife/node_show.rb` now wraps `Chef::Node.load` with a monotonic clock and emits:

```ruby
Chef::Log.debug("op=knife_node_show status=ok node=NAME elapsed_ms=T")
```

### Verification

```bash
# knife status — always visible at debug level (no env var needed)
knife status --log-level debug 2>&1 | grep op=knife_status

# Expected output on stderr:
# DEBUG: op=knife_status status=ok nodes=42 elapsed_ms=123

# knife node show — new hook
knife node show mynode --log-level debug 2>&1 | grep op=knife_node_show

# Expected output on stderr:
# DEBUG: op=knife_node_show status=ok node=mynode elapsed_ms=45
```

### Risk Notes

| Risk | Mitigation |
|------|-----------|
| `debug` verbosity | `debug` level is off by default; only visible when explicitly requested |
| `KNIFE_TIMING` behavior change | Still triggers `info`-level log — backward compatible |
| `node_show` timing overhead | Sub-microsecond monotonic clock read — no measurable impact |

### Test Coverage

- `spec/unit/knife/status_spec.rb`: updated to assert `Chef::Log.debug` called unconditionally; `info` only when `KNIFE_TIMING` set
- `spec/unit/knife/node_show_spec.rb`: new example asserts `Chef::Log.debug` called with `op=knife_node_show` pattern

### Rollback

```bash
git revert HEAD
```
