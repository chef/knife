# Ex13 — Feature Flag Lifecycle: KNIFE_TIMING

## Flag: `KNIFE_TIMING`

### Overview
Environment variable flag that gates the search timing log hook in `knife status`.
Introduced to make timing output opt-in (safer default for production environments
where `Chef::Log.info` output may be suppressed or noisy).

### Lifecycle

| Stage | Detail |
|-------|--------|
| **Created** | Ex13 — gating existing Ex9 timing hook |
| **Code path** | `lib/chef/knife/status.rb:82` |
| **Default state** | **OFF** — timing is NOT logged unless flag is set |
| **Enable** | `KNIFE_TIMING=1 knife status` (any non-empty value enables) |
| **Disable** | Unset the variable: `unset KNIFE_TIMING` |
| **Remove when** | Promoted to a proper `--timing` CLI flag or structured logging |

### Code Change
```ruby
# lib/chef/knife/status.rb
if ENV["KNIFE_TIMING"]
  Chef::Log.info("op=knife_status status=ok nodes=#{all_nodes.size} elapsed_ms=#{(search_elapsed * 1000).round}")
end
```

### Local Validation

**ON (`KNIFE_TIMING=1`):**
```
$ KNIFE_TIMING=1 bundle exec rspec spec/unit/knife/status_spec.rb -e "KNIFE_TIMING" --format documentation

search duration log hook (KNIFE_TIMING flag)
  when KNIFE_TIMING is set
    logs node count and elapsed time after search completes    ✓
    reports 0 nodes when search returns nothing                ✓
  when KNIFE_TIMING is not set (default OFF)
    does not log timing information                            ✓

3 examples, 0 failures
```

**OFF (`KNIFE_TIMING` unset):**
```
$ bundle exec rspec spec/unit/knife/status_spec.rb -e "KNIFE_TIMING" --format documentation

search duration log hook (KNIFE_TIMING flag)
  when KNIFE_TIMING is set
    logs node count and elapsed time after search completes    ✓
    reports 0 nodes when search returns nothing                ✓
  when KNIFE_TIMING is not set (default OFF)
    does not log timing information                            ✓

3 examples, 0 failures
```

### CI Validation
`.github/workflows/feature-flag-matrix.yml` runs a 2-job matrix:
- Job 1: `KNIFE_TIMING=1` (ON)
- Job 2: `KNIFE_TIMING=""` (OFF)

Both jobs post output to `$GITHUB_STEP_SUMMARY`. `continue-on-error: true` ensures advisory only.

### Rollback
```bash
# To revert the flag and restore always-on timing:
git revert HEAD
```

---

## Walk Ex13 — Feature Flag Lifecycle Update

### What Changed (Walk Ex9)

Walk Ex9 promoted `KNIFE_TIMING` from "gate all timing" to "gate info-level only". The `debug`-level timing log is now **always emitted** regardless of the flag.

| Behavior | Before Walk Ex9 (Crawl) | After Walk Ex9 (Walk) |
|----------|------------------------|----------------------|
| `debug` log | Never (hidden behind flag) | **Always** |
| `info` log | When `KNIFE_TIMING` set | When `KNIFE_TIMING` set |

### Corrected Flag Lifecycle

| Stage | Detail |
|-------|--------|
| **Purpose** | Gates the `info`-level structured timing line (for CI/scripting consumers of log output) |
| **Default state** | **OFF** — only `debug`-level timing is emitted by default |
| **Enable** | `KNIFE_TIMING=1 knife status` — adds `info`-level line alongside existing `debug` line |
| **Disable** | Unset: `unset KNIFE_TIMING` — `debug` line still emitted |
| **Remove when** | When `--log-level info` is the standard operator mode and the extra `info` line is no longer needed for differentiation |

### CI Matrix Update

`.github/workflows/feature-flag-matrix.yml` now:
- Runs **both** `status_spec.rb` and `node_show_spec.rb` (Walk Ex9 added timing to node_show too)
- Reports three rows in the summary:
  - `debug timing (always)` — ✅ present in both ON and OFF jobs
  - `info timing (flag only)` — ✅ present in ON job, ➖ off in OFF job (expected)
  - `Examples` — pass count

### ON/OFF Validation Output

**KNIFE_TIMING=1 (ON):**

| Check | Result |
|-------|--------|
| debug timing (always)   | ✅ present |
| info timing (flag only) | ✅ present |
| Examples                | 30 examples, 0 failures |

**KNIFE_TIMING unset (OFF):**

| Check | Result |
|-------|--------|
| debug timing (always)   | ✅ present |
| info timing (flag only) | ➖ off (expected) |
| Examples                | 30 examples, 0 failures |

### Local Validation

```bash
# ON — debug + info both present
KNIFE_TIMING=1 bundle exec rspec spec/unit/knife/status_spec.rb spec/unit/knife/node_show_spec.rb \
  --format documentation 2>&1 | grep -E "always logs|logs structured|load-time"

# OFF — only debug present
bundle exec rspec spec/unit/knife/status_spec.rb spec/unit/knife/node_show_spec.rb \
  --format documentation 2>&1 | grep -E "always logs|load-time"
```

### Rollback

```bash
git revert HEAD  # reverts feature-flag.md and feature-flag-matrix.yml to Crawl Ex13 state
```
