# Dependency Hygiene — Run Ex7

## Scope

Target: `knife.gemspec` runtime dependencies + `Gemfile.lock`  
Method: `bundle update <gem>` for lockfile bump; direct edits for constraint floor hygiene  
Validation: `bundle exec rspec spec/unit/` — **1421 examples, 0 failures**

---

## Changes Applied

### 1. `train-core` — Patch version bump (Gemfile.lock)

**Type**: Actual version upgrade  
**Command**: `bundle update train-core`

| | Before | After |
|---|---|---|
| Locked version | `3.16.2` | `3.16.3` |
| gemspec constraint | `~> 3.13, >= 3.13.4` | unchanged |

**Why**: Patch release within existing constraint. Picked up by `bundle outdated --strict`.  
**Rollback**:
```bash
git checkout HEAD~1 -- Gemfile.lock
bundle install
```

---

### 2. `net-ssh` — Raise lower bound (knife.gemspec)

**Type**: Constraint hygiene  
**File**: `knife.gemspec`

| | Before | After |
|---|---|---|
| Constraint | `>= 5.1, < 8` | `>= 7.0, < 8` |
| Locked version | `7.3.2` | `7.3.2` (unchanged) |

**Why**: `net-ssh` 5.x was released in 2018; 6.x in 2019. The repo has run 7.x in all CI
for over a year. Raising the floor to `>= 7.0` documents the actual tested minimum and
prevents accidental installs with a 5-year-old release that lacks modern key algorithms.  
**Rollback**:
```bash
git checkout HEAD~1 -- knife.gemspec
bundle install
```

---

### 3. `ffi` — Raise lower bound (knife.gemspec)

**Type**: Constraint hygiene  
**File**: `knife.gemspec`

| | Before | After |
|---|---|---|
| Constraint | `>= 1.15, < 1.18.0` | `>= 1.17, < 1.18.0` |
| Locked version | `1.17.4` | `1.17.4` (unchanged) |

**Why**: `ffi` 1.15 was released in 2021. All CI platforms (Ubuntu, macOS, Windows) have
been installing 1.17.x for every build. Raising the floor from 1.15 to 1.17 closes the
gap between the stated minimum and the actually-tested minimum.  
**Rollback**:
```bash
git checkout HEAD~1 -- knife.gemspec
bundle install
```

---

## Regression Evidence

```
bundle exec rspec spec/unit/

Finished in 1.53 seconds (files took 5.6 seconds to load)
1421 examples, 0 failures, 2 pending
```

No failures introduced by any of the three changes.

---

## Update Process for Future Dependency Hygiene Passes

1. Run `bundle outdated --strict` to identify gems upgradeable within current constraints.
2. Upgrade direct deps one-at-a-time: `bundle update <gem>` (scoped, never `bundle update` naked).
3. Run `bundle exec rspec spec/unit/` after each upgrade to catch regressions early.
4. For constraint floor hygiene: compare gemspec lower bounds against the locked version in `Gemfile.lock`; raise floors that lag by more than one major version.
5. Commit `Gemfile.lock` and `knife.gemspec` in the same commit so they are atomically reverted.
6. Document each change in this file with before/after and rollback command.

---

## Combined Rollback

```bash
# Revert the single commit that contains all three changes
git revert HEAD

# Reinstall to match reverted lockfile
bundle install
```
