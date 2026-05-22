# Crawl Track — Follow-up Backlog Epic

**Epic Issue:** [#121](https://github.com/chef/knife/issues/121)
**Source:** Crawl Track AI-assisted exercises Ex0–Ex11

---

## Child Issues

### [#116](https://github.com/chef/knife/issues/116) — Raise test line coverage from 47% to 70%+
**Code paths:** `lib/chef/knife/*.rb` — bootstrap, search, ssh are highest priority  
**Acceptance:**
- Line coverage ≥ 70% in CI job summary (currently 47.26%)
- New specs for ≥ 5 under-tested commands
- Coverage advisory job shows ✅

**Depends on:** Ex10 CI advisory job (merged)  
**Size:** Large — multiple PRs

---

### [#117](https://github.com/chef/knife/issues/117) — Extend observability timing to search, node list, and ssh
**Code paths:** `lib/chef/knife/search.rb`, `node_list.rb`, `ssh.rb`  
**Reference impl:** `lib/chef/knife/status.rb:66` (Ex9)  
**Acceptance:**
- Each command logs `returned N result(s) in Xs` at `Chef::Log.info`
- New specs verify log output per command

**Depends on:** Ex9 timing hook (merged)  
**Size:** Small — one PR per command

---

### [#118](https://github.com/chef/knife/issues/118) — Add Brakeman SAST scan to CI
**Code paths:** `.github/workflows/`, `lib/chef/knife/exec.rb`, `ssh.rb`  
**Acceptance:**
- `.github/workflows/sast.yml` runs Brakeman on every PR
- ≥ 1 finding triaged (fixed or justified ignore)
- `SECURITY.md` updated with SAST section

**Depends on:** Ex8 secret scan (merged)  
**Size:** Small

---

### [#119](https://github.com/chef/knife/issues/119) — Harden bootstrap argument validation
**Code paths:** `lib/chef/knife/bootstrap.rb`, `bootstrap/train_connector.rb`  
**Acceptance:**
- `validate_options!` raises structured error for missing host, invalid node name, conflicting flags
- Human-readable messages with offending value + hint
- New specs cover each validation branch

**Depends on:** Ex5 API hardening patterns (merged)  
**Size:** Medium

---

### [#120](https://github.com/chef/knife/issues/120) — Frozen string literals in high-frequency commands
**Code paths:** `lib/chef/knife/search.rb`, `node_list.rb`, `cookbook_list.rb`  
**Reference impl:** `lib/chef/knife/status.rb:37` `PARTIAL_SEARCH_FIELDS` (Ex6)  
**Acceptance:**
- `# frozen_string_literal: true` added to ≥ 3 commands
- Repeated literal arrays extracted to named frozen constants
- Full test suite passes, no behavior change

**Depends on:** Ex6 perf pattern (merged); safer after #116 (more coverage)  
**Size:** Small–Medium

---

## Dependency Graph

```
#118 (SAST)        ──── standalone
#117 (observe)     ──── standalone
#119 (bootstrap)   ──── standalone
#120 (frozen)      ──┐
                      └─ safer after #116 lands
#116 (coverage)    ──── start here
```

## Suggested Delivery Order
1. **#116** (coverage) + **#118** (SAST) — parallel, no deps
2. **#117** (observability) + **#119** (bootstrap) — parallel
3. **#120** (frozen literals) — after #116 lands
