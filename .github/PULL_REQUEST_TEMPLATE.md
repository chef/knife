## Summary
<!-- What does this PR do? One or two sentences. -->


## Evidence
<!-- Paste test output, screenshots, or CI job summary links. -->


## Review Focus
<!-- 3–5 bullets telling the reviewer exactly what to look at and why. -->
- [ ] **`path/to/file.rb`** — _describe what changed and why it matters_
- [ ] **Tests** — _confirm new/modified specs cover the change_
- [ ] **Edge cases** — _any boundary conditions or error paths to verify_


## Verification Steps
<!-- Steps a reviewer can run locally to confirm the change works. -->
```bash
# 1. Install dependencies
bundle install

# 2. Run the relevant spec(s)
bundle exec rspec spec/unit/knife/<relevant_spec>.rb

# 3. Run the full suite to check for regressions
bundle exec rake spec
```


## Risk
<!-- Low / Medium / High — and why. -->
Low

## Rollback
<!-- How to undo this change if something goes wrong. -->
```bash
git revert <commit-sha>
# or: pin the previous version in Gemfile and run bundle install
```
