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
