# Ex5 — API / Contract Hardening

## Target subsystem
`lib/chef/knife/bootstrap.rb` — the `Bootstrap` command's validation layer.  
Spec: `spec/unit/knife/bootstrap_spec.rb`

---

## TODO / Gap scan findings

Scanned `lib/chef/knife/` for TODOs and FIXMEs; 19 found in total.  
Boundary-relevant findings selected for Ex5:

| # | Location | Finding | Action |
|---|----------|---------|--------|
| 1 | `bootstrap.rb:787` `#validate_name_args!` | Only `nil` was guarded. Empty string `""` passed through silently — a caller passing `name_args[0] = ""` would bootstrap nothing and the error surfaced later (or not at all). | **Fixed**: added `|| server_name.strip.empty?` guard. |
| 2 | `bootstrap_spec.rb:2305` comment `# TODO - don't we still send validation key?` | Plaintext + SSL + validation_key_exists path returned `true` with no explanation. Rationale was undocumented. | **Documented**: annotated test with rationale — SSL transport encrypts the WinRM channel, so even if the validation key is transmitted it is not exposed in plaintext. The TODO is answered in-place. |
| 3 | `bootstrap.rb:764-765` `#validate_winrm_transport_opts!` | Inline comment read "TODO test for this method" (added when the method was extracted). Method already has full test coverage (8 cases). | **Resolved**: comment is historical artifact. No new tests needed; existing coverage is adequate. |

---

## Contract tests added

### `#validate_name_args!` — `spec/unit/knife/bootstrap_spec.rb`

```
describe "#validate_name_args!" do
  context "when no host is provided (nil server_name)"
    → exits with error "Must pass an FQDN or ip to bootstrap"
  context "when an empty string is provided as server_name"
    → exits with error (edge case — was previously unguarded)
  context "when a valid FQDN is provided"
    → returns without error (happy path)
end
```

**Rationale per case**:

- **nil** — pre-existing guard, confirmed via direct test (previously only mocked).
- **empty string** — new boundary. `""` and `"  "` are semantically equivalent to nil for this method. Adding the guard prevents silent mis-bootstrap.
- **valid FQDN** — regression baseline. Confirms the guard does not over-reject.

---

## Code change

File: `lib/chef/knife/bootstrap.rb`, method `#validate_name_args!`

```diff
- if server_name.nil?
+ if server_name.nil? || server_name.strip.empty?
```

Risk: **Low** — broadens an existing guard. No caller passes intentionally empty strings; the change rejects a previously-undefined input.

---

## Update process for future boundary changes

1. **Scan first** — run `grep -rn "TODO\|FIXME" lib/chef/knife/` before touching any boundary method.
2. **Document gap** — add a row to the findings table above before writing code.
3. **Write test first** — add the failing test case in the spec, confirm it fails, then fix the code.
4. **Keep rationale inline** — add a `# Rationale:` comment in the spec above each edge-case test.
5. **Run targeted spec** — `bundle exec rspec spec/unit/knife/bootstrap_spec.rb` before committing.
6. **Update this doc** — add new rows to the findings table and update the contract tests section.

---

## Test run evidence

```
bundle exec rspec spec/unit/knife/bootstrap_spec.rb \
  -e "validate_name_args" --format documentation

Chef::Knife::Bootstrap
  #validate_name_args!
    when no host is provided (nil server_name)
      exits with an error message
    when an empty string is provided as server_name
      exits with an error message
    when a valid FQDN is provided
      returns without error

3 examples, 0 failures
```

---

## Rollback

```bash
git revert HEAD   # reverts bootstrap.rb fix and spec additions
```

The nil-only guard is restored; the new edge-case tests are removed.
