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
