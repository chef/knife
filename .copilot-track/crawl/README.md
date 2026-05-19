# GHCP Crawl Track — README

Welcome to the **Crawl** phase of the GitHub Copilot Proficiency (GHCP) learning track for this repository.

---

## What Is the Crawl Track?

The Crawl track builds foundational skills for using GitHub Copilot effectively in a real codebase. You'll orient yourself in the repo, identify safe change zones, make a small tested change, and document everything using Copilot as a tool — not a crutch.

---

## Chain-PRs Explained

Each exercise produces its own branch and PR, but they **chain** off each other rather than all targeting `main`:

```
main
 └── learn/crawl/<name>-ex0-bootstrap   ← PR → main
       └── learn/crawl/<name>-ex1-orientation  ← PR → ex0 branch
             └── learn/crawl/<name>-ex2-...    ← PR → ex1 branch
```

**Why chain?**
- Keeps each PR's diff small and focused on that exercise only.
- Lets reviewers see incremental progress without noise from earlier steps.
- Mirrors real feature-branch workflows where work builds on previous work.

**Practical rule:** Always `git checkout` the *previous* exercise branch before creating the next one.

---

## Evidence in PRs

Every PR description should include an **Evidence** section that links to or quotes the artifact proving you completed the exercise. Examples:

| Exercise | Evidence |
|----------|----------|
| Ex0 Bootstrap | Files exist in `ai-track-docs/` and `.copilot-track/crawl/` |
| Ex1 Orientation | `ai-track-docs/SYSTEM-OVERVIEW.md` filled in with entry points + low-risk module |
| Ex2+ | Test output, diff link, or screenshot of passing tests |

This makes reviews fast and self-documenting.

---

## Prompt Usage Guidelines

1. **Use the Mini Prompts verbatim first.** They are calibrated to get useful output. Modify only after the first attempt fails.
2. **One goal per prompt.** Don't chain unrelated asks in a single message.
3. **Ask for file paths.** Always end orientation prompts with: *"Include concrete file/folder paths."*
4. **Validate before accepting.** Check that Copilot's suggestions don't touch submodules, vendor directories, or security-sensitive code.
5. **Iterate, don't regenerate.** If output is almost right, reply with a correction rather than starting over.

---

## Folder Structure

```
ai-track-docs/
  SYSTEM-OVERVIEW.md   ← Filled in Exercise 1; updated each exercise
  build-test.md        ← How to build and run tests
  architecture.mmd     ← Mermaid diagram of high-level architecture

.copilot-track/crawl/
  README.md            ← This file
```

---

*Created as part of the GHCP Crawl Bootstrap (Exercise 0).*
