# Ex6 — Performance Micro-Optimization

## Candidate Identification

**File**: `lib/chef/knife/status.rb`  
**Method**: `#build_search_opts`  
**Issue**: The method allocated a new nested Hash (`filter_result:` with 8 string-array pairs) on **every search call**. In long-running or scripted usage (e.g. piped knife status in a loop), this adds up to redundant GC pressure.

---

## Baseline Measurement (BEFORE)

```ruby
# BEFORE: fresh hash allocation on each call
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

```
Benchmark: build_search_opts called 100_000 times (long_output=false)
                               user     system      total        real
BEFORE (new hash each call):  0.043407   0.000829   0.044236 (  0.044446)
```

---

## Optimization Applied

Extract the partial-search hash to a **frozen constant** (`PARTIAL_SEARCH_FIELDS`).  
The constant is allocated once at class load time and reused on every call.

```ruby
# AFTER: frozen constant — zero allocation per call
PARTIAL_SEARCH_FIELDS = { filter_result:
    { name: ["name"], ipaddress: ["ipaddress"], ohai_time: ["ohai_time"],
      cloud: ["cloud"], run_list: ["run_list"], platform: ["platform"],
      platform_version: ["platform_version"],
      chef_environment: ["chef_environment"] } }.freeze

def build_search_opts
  config[:long_output] ? {} : PARTIAL_SEARCH_FIELDS
end
```

---

## After Measurement (AFTER)

```
Benchmark: build_search_opts called 100_000 times (long_output=false)
                               user     system      total        real
AFTER  (frozen constant):     0.002860   0.000021   0.002881 (  0.002882)
```

**Result: ~15x faster** (44ms → 2.9ms per 100k calls)

---

## Safety Analysis

| Concern | Assessment |
|---------|-----------|
| Mutation risk | Callers receive the frozen constant — any attempt to mutate raises `FrozenError`. The downstream `Chef::Search::Query` only reads the hash; it never mutates it. Safe. |
| Behavior change | Return value is structurally identical to the old inline hash. No caller relies on object identity. |
| `long_output` path | Still returns a fresh `{}` — unchanged. |
| Test coverage | All 18 existing examples pass, including direct tests for `#build_search_opts`. |

---

## Test Evidence

```
bundle exec rspec spec/unit/knife/status_spec.rb --format documentation

Chef::Knife::Status
  ...
  #build_search_opts
    returns filter_result opts by default
    returns empty hash when long_output is set
  ...

18 examples, 0 failures
```

---

## Rollback

```bash
git revert HEAD  # removes constant + restores inline hash allocation
```

---

## Walk Ex6 — Micro-Optimization: StatusPresenter#summarize String Building

### Candidates

**File**: `lib/chef/knife/core/status_presenter.rb`, `summarize` method

#### 1. O(n²) string concatenation (line 123)

Before:
```ruby
summarized = "#{summarized}#{line_parts.join(", ")}.\n"
```
Each iteration allocates a new string that copies the entire accumulated result.
This is O(n²) in the number of nodes displayed.

After:
```ruby
summarized << "#{line_parts.join(", ")}.\n"
```
Shovel operator appends in-place. O(1) per node — O(n) total.

#### 2. Redundant `.dup` allocation (lines 119-121)

Before:
```ruby
platform = node["platform"].dup
if node["platform_version"]
  platform << " #{node["platform_version"]}"
end
```
`.dup` copies the string only to potentially discard the copy. The `<<` mutates
the copy, not the original attribute — the `.dup` is unnecessary defensive code.

After:
```ruby
platform = if node["platform_version"]
               "#{node["platform"]} #{node["platform_version"]}"
             else
               node["platform"]
             end
```
Single allocation, no copy.

### Benchmark Evidence

Measured with `Benchmark.bm` on inline Ruby, simulating the concat loop:

| n nodes | Before (concat) | After (shovel) | Speedup |
|---------|----------------|----------------|---------|
| 1 000   | 0.051 ms       | 0.033 ms       | 1.5×    |
| 10 000  | 2.628 ms       | 0.321 ms       | **8.2×** |

### Safety

- Both changes are behavior-preserving; output is identical.
- 38 existing spec examples (status_spec + status_presenter_spec) remain green.
- The optimization matters most for large fleets (1 000+ nodes) where
  `knife status` output is piped to scripts.

### Rollback

```bash
git revert HEAD  # reverts both lines in a single commit
```
