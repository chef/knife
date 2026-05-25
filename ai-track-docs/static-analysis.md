# Run Ex14 — Type Safety / Static Analysis

**Level**: Run | **Exercise**: 14 | **Branch**: `learn/run/nikhil-ex14-static-analysis`

## Goal

Increase static analysis strictness for `lib/chef/knife/core/`, fix the highest-signal
findings, document suppressions with justification, and provide an autofix script.

---

## Baseline (before this PR)

```
$ bundle exec rubocop lib/chef/knife/core/ --format progress
16 files inspected, no offenses detected
```

The folder was already clean under base ChefStyle rules.

**After enabling `Style/ConditionalAssignment`:**

```
16 files inspected, 8 offenses detected, 8 offenses auto-correctable
```

| File | Line | Cop |
|------|------|-----|
| `hashed_command_loader.rb` | 44 | Style/ConditionalAssignment |
| `node_presenter.rb` | 80 | Style/ConditionalAssignment |
| `status_presenter.rb` | 80 | Style/ConditionalAssignment |
| `windows_bootstrap_context.rb` | 84, 90, 423 | Style/ConditionalAssignment |
| `bootstrap_context.rb` | 2 sites | Style/ConditionalAssignment |
| **Total** | | **8** |

---

## After (this PR)

```
$ bundle exec rubocop lib/chef/knife/core/ --only Style/ConditionalAssignment,...
16 files inspected, no offenses detected
```

**Before: 8 offenses → After: 0 offenses**

---

## Fix Applied: Style/ConditionalAssignment

All 8 offenses were correctable and applied via `bundle exec rubocop --autocorrect`.

**Pattern fixed** (example from `hashed_command_loader.rb`):

```ruby
# Before — if/else for variable assignment
if condition
  var = value_a
else
  var = value_b
end

# After — return value of conditional assigned directly
var = if condition
        value_a
      else
        value_b
      end
```

### `.rubocop.yml` addition

```yaml
Style/ConditionalAssignment:
  Include:
    - "lib/chef/knife/core/**/*.rb"
```

---

## Suppressions (Documented)

### Metrics/MethodLength

**Files suppressed**: `bootstrap_context.rb`, `windows_bootstrap_context.rb`

**Findings if enabled**: 8 violations (methods 15–70 lines)

**Justification**: These files contain methods that generate multi-section
`chef-client` config strings and PowerShell bootstrap scripts. The length
is inherent to the template structure, not algorithmic complexity. Extracting
sub-sections would distribute the same string-building logic across more methods
without improving testability or readability.

**Suppression**:

```yaml
Metrics/MethodLength:
  Exclude:
    - "lib/chef/knife/core/bootstrap_context.rb"
    - "lib/chef/knife/core/windows_bootstrap_context.rb"
```

**Review trigger**: If either file grows significantly, revisit and consider
extracting a dedicated config builder class.

---

## Autofix Script

`scripts/autofix-static-analysis.sh` applies all correctable cops in one command:

```bash
# Dry run — show findings without changing files
bash scripts/autofix-static-analysis.sh --dry-run

# Apply all corrections, verify, run specs
bash scripts/autofix-static-analysis.sh
```

**Cops covered**: Style/ConditionalAssignment, Style/StringConcatenation,
Style/GuardClause, Style/FrozenStringLiteralComment

---

## Regression Evidence

```
306 examples, 0 failures, 1 pending  (spec/unit/knife/core/)
```

---

## Rollback

```bash
git revert HEAD
```
