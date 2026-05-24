# Ex12 — Backlog Epic: PR Hygiene and Future Work

## Goal
Translate Crawl Track exercise findings into 5 structured GitHub Issues linked
to specific code paths, with acceptance criteria and a dependency graph.

## Epic Issue
[#121 — Crawl Track: Follow-up backlog](https://github.com/chef/knife/issues/121)

## Child Issues Created

| Issue | Title | Size |
|-------|-------|------|
| [#116](https://github.com/chef/knife/issues/116) | Raise test coverage 47% → 70%+ | Large |
| [#117](https://github.com/chef/knife/issues/117) | Extend observability timing to search/node/ssh | Small |
| [#118](https://github.com/chef/knife/issues/118) | Add Brakeman SAST scan to CI | Small |
| [#119](https://github.com/chef/knife/issues/119) | Harden bootstrap argument validation | Medium |
| [#120](https://github.com/chef/knife/issues/120) | Frozen string literals in high-frequency commands | Small |

## Files Added
- `docs/backlog.md` — full backlog doc with code path links and dependency graph
- GitHub Issues #116–#121 created with acceptance criteria

## Backlog Doc Path
`docs/backlog.md`

---

## Walk Ex12 — Backlog Grooming

### Epic Issue
[#145 — Walk Track: Follow-up backlog](https://github.com/chef/knife/issues/145)

### Child Issues Created

| Issue | Title | Size |
|-------|-------|------|
| [#140](https://github.com/chef/knife/issues/140) | Extend `test_mandatory_field` to remaining commands | Medium |
| [#141](https://github.com/chef/knife/issues/141) | Contract tests for NodePresenter JSON boundary | Small |
| [#142](https://github.com/chef/knife/issues/142) | Extend debug timing to search, node_list, ssh | Small |
| [#143](https://github.com/chef/knife/issues/143) | Add doc link-checker CI step | Small |
| [#144](https://github.com/chef/knife/issues/144) | Add Brakeman SAST scan to CI | Small |

### Source Exercises

| Issue | Sourced from |
|-------|-------------|
| #140 | Walk Ex3 — identified 15+ remaining inline nil-guard blocks |
| #141 | Walk Ex5 — contract tests only cover StatusPresenter |
| #142 | Walk Ex9 — timing only covers status + node_show |
| #143 | Walk Ex4/Ex11 — docs grew with no link validation |
| #144 | Walk Ex8 — secret scan in place; SAST still missing |

### Backlog Doc Path
`docs/backlog-walk.md`
