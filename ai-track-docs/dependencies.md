# Ex7 — Dependency Hygiene

## Goal
Improve maintainability and predictability. Document critical dependencies,
current pinning strategy, and propose minimal constraints where needed.

---

## Critical Dependencies

| Gem | Constraint | Why Constrained | Risk if Unpinned |
|-----|-----------|-----------------|-----------------|
| `train-core` | `~> 3.13, >= 3.13.4` | Core transport API — breaking changes likely across minors | High |
| `ffi` | `>= 1.15, < 1.18.0` | Native extension — ABI compatibility; < 1.18.0 blocks known breakage | High |
| `ffi-yajl` | `~> 2.2` | JSON parser with C extension; patch-safe with `~>` | Medium |
| `chef-licensing` | `~> 1.2` | License enforcement — minor bumps may add prompts | Medium |
| `train-winrm` | `>= 0.2.17` | Lower-bounded only; Windows transport | Low |
| `chef-vault` | unpinned | Companion gem; tracks chef ecosystem | Low |

---

## Current Pinning Strategy

- **Pessimistic (`~>`)**: Used for gems with native extensions or Chef API surface (`train-core`, `ffi-yajl`, `chef-licensing`) — allows patch updates only
- **Range (`>=` + `<`)**: Used for `ffi` to block a specific known-bad version range
- **Lower-bound only**: Used for `train-winrm` and `chef-vault` — lower risk, follow ecosystem

---

## Pinning Recommendations

| Gem | Current | Proposed | Rationale |
|-----|---------|----------|-----------|
| `ffi-yajl` | `~> 2.2` | `~> 2.7` | Lock to current minor; 2.7.x is stable and drops `yajl` transitive dep |
| `chef-vault` | unpinned | `>= 4.0` | Add lower bound for security fix in 4.0 |

---

## How to Check Outdated Dependencies

```bash
bundle outdated
# Or check a specific gem:
bundle outdated ffi-yajl
```

## How to Update Safely (one gem at a time)

```bash
# Conservative: only update the specified gem, keep everything else pinned
bundle update --conservative ffi-yajl

# Verify nothing broke
bundle exec rake spec
```

## Rollback

```bash
# Pin back to previous version in Gemfile:
# gem "ffi-yajl", "~> 2.7.7"
# then:
bundle install
```

## Policy Notes
- Never run bare `bundle update` — updates all gems simultaneously, hard to bisect regressions
- Always run full test suite after any dependency change
- Update `Gemfile.lock` only via `bundle update --conservative <gem>`
- Transitive dependency changes (e.g. dropped `yajl`) count as a dep hygiene event — document in PR
