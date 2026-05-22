# Ex7 — Dependency Upgrade

## Selected Dependency

| | Value |
|---|---|
| **Gem** | `ffi-yajl` |
| **Before** | 2.7.7 |
| **After** | 2.7.11 |
| **Type** | Patch-level bump (4 patch releases) |
| **Declared constraint** | `~> 2.2` in `knife.gemspec` — no gemspec change needed |
| **Role** | Core JSON encode/decode library used throughout Chef tooling |

## Upgrade Rationale

- `ffi-yajl` is a direct dependency of `knife.gemspec` and is widely used for JSON parsing across the Chef ecosystem.
- The 2.7.7 → 2.7.11 jump is patch-level: no API changes, only bug fixes and native extension improvements.
- Running within the existing `~> 2.2` constraint means no gemspec edit is required — Bundler resolves cleanly.
- No other gems were updated (used `--conservative` flag to pin everything else).

## Gemfile.lock Diff

```diff
-    ffi-yajl (2.7.7)
+    ffi-yajl (2.7.11)
       libyajl2 (>= 2.1)
-      yajl
...
-    yajl (0.3.4)
```

`ffi-yajl 2.7.11` dropped its transitive `yajl` dependency — one fewer gem in the lockfile.

## Upgrade Command

```bash
bundle update ffi-yajl --conservative
```

## Test Evidence

```
bundle exec rspec spec/unit/ --format progress

Finished in 3.91 seconds (files took 3.52 seconds to load)
1351 examples, 0 failures, 2 pending
```

2 pending examples are pre-existing (terminal color + randomization isolation) — unrelated to this upgrade.

## Impact Assessment

| Area | Impact |
|------|--------|
| JSON parsing behavior | None — patch release, no API changes |
| Native extension ABI | Rebuilt automatically by Bundler on install |
| Other gems | None — `--conservative` flag kept all other gems pinned |
| CI | Expected to pass (no code changes, only lockfile) |

## Rollback

```bash
# Option 1: pin previous version temporarily in Gemfile
gem "ffi-yajl", "2.7.7"
bundle install

# Option 2: restore previous Gemfile.lock from git
git checkout HEAD~1 -- Gemfile.lock
bundle install
```
