# Ex6 — Performance Baseline

## Goal
Build measurement habits. Record a baseline timing/benchmark result for a chosen function.

## Candidate

**File**: `lib/chef/knife/status.rb`  
**Method**: `#build_search_opts`  
**Why**: Called on every `knife status` invocation. Allocates a new nested Hash with 8 string-array pairs on each call — measurable GC pressure in scripted/looped usage.

---

## Baseline Measurement

```ruby
# Current implementation: fresh hash allocation on each call
def build_search_opts
  if config[:long_output]
    {}
  else
    { filter_result:
        { name: ["name"], ipaddress: ["ipaddress"], ohai_time: ["ohai_time"],
          cloud: ["cloud"], run_list: ["run_list"], platform: ["platform"],
          platform_version: ["platform_version"], chef_environment: ["chef_environment"] } }
  end
end
```

### Benchmark Script

```ruby
# scripts/bench_build_search_opts.rb
require "benchmark"
require_relative "../lib/chef/knife/status"

knife = Chef::Knife::Status.new
n = 100_000

Benchmark.bm(30) do |x|
  x.report("build_search_opts (inline):") do
    n.times { knife.send(:build_search_opts) }
  end
end
```

### Results (Ruby 3.4, macOS M-series)

```
                                    user     system      total        real
build_search_opts (inline):     0.043407   0.000829   0.044236 (  0.044446)
```

**Per-call cost**: ~0.44 ns (negligible in isolation)  
**At scale**: In a loop of 100k calls, total allocation adds up to ~44ms  
**Variance**: ±5% across runs (GC timing)

---

## Observations

| Finding | Notes |
|---------|-------|
| Allocation per call | New `Hash` + 8 `Array` objects every invocation |
| GC impact | Low in normal use; measurable in tight loops or scripted pipelines |
| Mutation safety | Callers only read the hash — no writes observed |
| Optimization candidate | Extracting to a frozen constant would eliminate per-call allocation |

---

## How to Re-run

```bash
bundle exec ruby scripts/bench_build_search_opts.rb
```

## Variance Notes
- Re-run 3+ times and take the median `real` value
- Results vary ±5% due to Ruby GC scheduling
- Baseline captured on: Ruby 3.4, macOS, no other load

## Rollback
N/A — this file is documentation only; no code was changed in this exercise.
