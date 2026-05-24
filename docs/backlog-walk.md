# Walk Track — Follow-up Backlog Epic

**Epic Issue:** [#145](https://github.com/chef/knife/issues/145)
**Source:** Walk Track AI-assisted exercises Ex1–Ex11

---

## Child Issues

### [#140](https://github.com/chef/knife/issues/140) — Extend `test_mandatory_field` refactor to remaining knife commands
**Code paths:**
- `lib/chef/knife/node_edit.rb:43`
- `lib/chef/knife/role_create.rb:42`
- `lib/chef/knife/client_edit.rb:36`
- `lib/chef/knife/cookbook_download.rb:60`
- `lib/chef/knife/environment_show.rb:38`
- `lib/chef/knife/ssh.rb:612`
- `lib/chef/knife/tag_list.rb:38`
- `lib/chef/knife/role_delete.rb:37`
- `lib/chef/knife/user_reregister.rb:41`
- (run `grep -rn 'ui.fatal.*must specify' lib/` for full list)

**Acceptance:**
- All inline nil-guard blocks replaced with `test_mandatory_field`
- No behavior change — existing specs pass
- Net line reduction ≥ 30 lines

**Depends on:** Walk Ex3 refactor pattern (merged)
**Size:** Medium — one PR, pure refactor

---

### [#141](https://github.com/chef/knife/issues/141) — Add contract tests for NodePresenter JSON boundary
**Code paths:**
- `lib/chef/knife/core/node_presenter.rb` — `format_for_display` JSON path
- `spec/unit/knife/core/node_presenter_spec.rb` — add contract describe block
- `spec/data/node_presenter_contract.json` — new golden file

**Acceptance:**
- ≥ 8 assertions covering required JSON keys (`name`, `chef_environment`, `run_list`, `normal`)
- Golden file committed with non-deterministic fields zeroed/omitted
- Contract test runs in `bundle exec rake spec` with 0 failures
- `ai-track-docs/contract-test.md` updated

**Depends on:** Walk Ex5 contract pattern (merged)
**Size:** Small

---

### [#142](https://github.com/chef/knife/issues/142) — Extend debug-level timing to search, node_list, ssh
**Code paths:**
- `lib/chef/knife/search.rb` — wrap search call with `CLOCK_MONOTONIC`
- `lib/chef/knife/node_list.rb` — wrap list query
- `lib/chef/knife/ssh.rb` — wrap SSH session setup

**Acceptance:**
- Each command emits `Chef::Log.debug("op=knife_<cmd> status=ok elapsed_ms=N")` after main I/O
- One new spec per command asserting debug called with timing pattern
- cookstyle passes; existing specs green
- `ai-track-docs/observability.md` updated

**Depends on:** Walk Ex9 timing pattern (merged)
**Size:** Small

---

### [#143](https://github.com/chef/knife/issues/143) — Add doc link-checker CI step
**Code paths:**
- `.github/workflows/link-check.yml` — new advisory workflow using `lychee-action`
- `docs/`, `ai-track-docs/`, `CONTRIBUTING.md`, `README.md`

**Acceptance:**
- Workflow runs `lychee` on all `.md` files on every PR
- `continue-on-error: true` (advisory, non-blocking)
- `.lycheeignore` excludes known rate-limited URLs
- At least one broken link found and fixed or justified

**Depends on:** None
**Size:** Small

---

### [#144](https://github.com/chef/knife/issues/144) — Add Brakeman SAST scan to CI
**Code paths:**
- `.github/workflows/sast.yml` — new CI workflow
- `lib/chef/knife/exec.rb` — arbitrary Ruby execution
- `lib/chef/knife/ssh.rb` — shell command construction
- `SECURITY.md` — add SAST section

**Acceptance:**
- Workflow runs `brakeman --no-pager` on every PR
- `continue-on-error: true` initially; promote to blocking after first clean run
- At least one finding triaged (fixed or justified in `.brakeman.ignore`)
- `SECURITY.md` updated with SAST section

**Depends on:** Walk Ex8 pattern (merged)
**Size:** Small

---

## Dependency Graph

```
#143 (link check)   ── standalone
#144 (SAST)         ── standalone
#142 (timing)       ── follows Walk Ex9 pattern (merged)
#141 (NodePresenter)── follows Walk Ex5 pattern (merged)
#140 (refactor)     ── start here; safer after #141 adds coverage
```

## Suggested Delivery Order

1. **#143** + **#144** — parallel, CI-only, no source changes
2. **#142** + **#141** — parallel, follow established patterns
3. **#140** — after #141 increases coverage safety net
