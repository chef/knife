# Copilot Crawl — README

This folder stores artifacts produced by AI-assisted development sessions:
prompt records, evidence snapshots, and chain-PR metadata.

---

## Chain-PRs

A **chain-PR** is a sequence of pull requests where each PR builds on the
previous one's merge commit, forming a linear dependency chain:

```
main ──► PR-1 (base: main)
              └──► PR-2 (base: PR-1 branch)
                        └──► PR-3 (base: PR-2 branch)
```

### Why use chain-PRs?

- Break large features into reviewable, independently-mergeable slices.
- Each PR can be reviewed, tested, and approved without waiting for the full
  feature to be complete.
- Keeps `main` green at every merge point.

### Workflow rules

1. Name branches with a shared prefix: `PROJ-123/step-1`, `PROJ-123/step-2`, …
2. Set each PR's **base branch** to the *previous* step's branch (not `main`).
3. Re-target downstream PRs to `main` after the upstream PR merges (GitHub
   does this automatically when the base branch is deleted on merge).
4. Include a `Depends on #<PR>` line in the PR description so reviewers can
   navigate the chain.

---

## Evidence in PRs

Every AI-assisted PR **must** include evidence that the implementation meets
its acceptance criteria.  Place evidence in the PR description under a
collapsible section:

```markdown
<details>
<summary>Evidence – test run & coverage</summary>

\`\`\`
bundle exec rake spec
...
Coverage: 85.2 %   (1 052 / 1 234 lines)
All 312 examples, 0 failures
\`\`\`

</details>
```

### Accepted evidence types

| Type | How to capture |
|------|----------------|
| Test run output | `bundle exec rake spec 2>&1 \| tee evidence/test-run.txt` |
| Coverage summary | Last lines of the SimpleCov report |
| Linter output | `bundle exec cookstyle 2>&1 \| tail -5` |
| Manual smoke test | Screenshot or terminal transcript |

Store raw evidence files in this folder as `crawl/<JIRA-ID>-<step>-evidence.txt`.

---

## Prompt Usage

Prompts used during a session are saved here so they can be:

- **Reproduced** – re-run the same prompt against a future version of the code.
- **Audited** – understand *why* a particular change was made.
- **Refined** – iterate on prompt quality over time.

### File naming convention

```
crawl/<JIRA-ID>-<step>-prompt.md
```

Example: `crawl/KNIFE-42-step-2-prompt.md`

### Prompt file format

```markdown
# Prompt — KNIFE-42 step 2

**Date**: YYYY-MM-DD  
**Model**: claude-sonnet-4.6  
**Phase**: Implementation (Phase 2)

## System context fed to model

> (paste relevant sections of copilot-instructions.md or custom context)

## User prompt

> (exact text sent to the model)

## Key decisions made

- Used `double` instead of `instance_double` because the class is not loaded at spec time.
- Skipped integration test for node bootstrap; covered by functional spec.

## Outcome

PR #123 — all tests green, coverage 86 %.
```

---

## Folder Structure

```
.copilot-track/
└── crawl/
    ├── README.md                  ← this file
    ├── <JIRA-ID>-<step>-prompt.md
    └── <JIRA-ID>-<step>-evidence.txt
```

Do **not** commit secrets, API keys, or Chef server credentials into this folder.
