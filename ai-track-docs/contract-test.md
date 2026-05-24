# Contract Test: StatusPresenter JSON Output

## Walk Ex5 — API/Contract Hardening

### Contract Surface

**Method**: `Chef::Knife::Core::StatusPresenter#summarize_json(list)`  
**File**: `lib/chef/knife/core/status_presenter.rb`  
**Consumer**: `knife status --format json`

This method is the JSON API boundary between the knife status command and any
consumer that parses its output (scripts, dashboards, CI checks).

### Guaranteed Fields (always present)

| Field | Type | Notes |
|-------|------|-------|
| `name` | String | Node name |
| `chef_environment` | String / nil | Chef environment assignment |
| `ohai_time` | Numeric | Unix timestamp of last check-in |

### Optional Fields (present only when data exists)

| Field | Present when | Key name (do not rename) |
|-------|-------------|--------------------------|
| `ip` | Node has `ipaddress` or cloud public IPv4 | `ip` (not `ipaddress`) |
| `fqdn` | Node has `fqdn` or cloud public hostname | `fqdn` |
| `platform` | Node has `platform` attribute | `platform` |
| `platform_version` | Node has `platform_version` attribute | `platform_version` |
| `run_list` | `--run-list` flag passed | `run_list` |
| `default` / `override` / `automatic` | `--long-output` flag passed | attribute hashes |

### Golden File

`spec/data/status_presenter_contract.json` — snapshot of a fully-populated
node with `run_list` and `long_output` disabled (default invocation). The
`ohai_time` value is fixed to `0` to prevent timestamp drift.

### Running the Contract Tests

```bash
bundle exec rspec spec/unit/knife/core/status_presenter_spec.rb
```

The contract tests live in the `describe "contract: summarize_json output schema"` block.

### Updating the Contract Intentionally

If `summarize_json` is modified in a way that changes the output shape (e.g., a
field is renamed, added, or removed), follow these steps:

1. Make the code change in `lib/chef/knife/core/status_presenter.rb`
2. Run the specs — the golden file test will fail with a diff showing exactly what changed
3. Review the diff: confirm the change is intentional and not a regression
4. Regenerate the golden file:
   ```bash
   bundle exec rspec spec/unit/knife/core/status_presenter_spec.rb \
     -e "matches the golden file snapshot" --format documentation
   ```
   Then update `spec/data/status_presenter_contract.json` to match the new output
5. Update the **Guaranteed Fields** or **Optional Fields** tables above
6. Call out the schema change explicitly in the PR description under a
   "Contract Change" heading so reviewers know it is intentional

### What Counts as a Breaking Change

- Renaming a guaranteed field (e.g., `ohai_time` → `last_seen`)
- Removing a guaranteed field
- Changing the type of a guaranteed field (e.g., `ohai_time` from Numeric to String)
- Renaming an optional field (e.g., `ip` → `ipaddress`)

Breaking changes should be called out in the CHANGELOG and PR description.

---

# Contract Test: GenericPresenter Output Boundaries

## Run Ex5 — API/Contract Hardening

### Contract Surface

**File**: `lib/chef/knife/core/generic_presenter.rb`  
**Consumers**: All 149 knife subcommands via `format_for_display` and `format_list_for_display`

`GenericPresenter` is the highest-fan-out boundary in the codebase. Changing any
public method here affects every `knife * show` and `knife * list` command.

---

### Boundary A — `format_list_for_display(list)`

| Config | Return shape | Notes |
|--------|-------------|-------|
| Default (no flags) | `Array<String>` — keys sorted A–Z | Stable alphabetical order required by scripts |
| `config[:with_uri] = true` | Original `Hash` unchanged | Scripts use URI values directly |
| Empty input | `[]` (not nil) | Callers do not guard against nil |

**Spec location**: `spec/unit/knife/core/generic_presenter_spec.rb` — `contract: format_list_for_display`

---

### Boundary B — `format_for_display(data)`

| Config flag | Return shape | Rationale |
|-------------|-------------|-----------|
| None | `data` unchanged (passthrough) | Zero-cost default; ui.output formats it |
| `config[:id_only]` | Bare String (name or id) | Scripted enumeration — not a Hash |
| `config[:environment]` | `{"chef_environment" => String}` | Key name is stable; scripts parse it |
| `config[:attribute]` | `{name => {attr => value}}` | Subset extraction; stable nesting shape |
| `config[:run_list]` | `{name => {"run_list" => Array}}` | Key name `"run_list"` must not change |

**Spec location**: `spec/unit/knife/core/generic_presenter_spec.rb` — `contract: format_for_display`

---

### Boundary C — `format_data_subset_for_display` / `extract_nested_value`

- Calling `format_for_display` with `config[:attribute]` or `config[:run_list]` set (but nil values) raises `ArgumentError` — **this is intentional**: silent nil would produce empty output with no diagnostic.
- Dot-separated attribute paths (e.g. `"automatic.platform"`) return nil on missing intermediate keys — no exception raised.
- Array elements are accessed via numeric string index (e.g. `"arr.0"`).

---

### Updating the GenericPresenter Contract

1. Make the code change in `lib/chef/knife/core/generic_presenter.rb`
2. Run: `bundle exec rspec spec/unit/knife/core/generic_presenter_spec.rb`
3. If a contract test fails, confirm the change is intentional
4. Update the failing example to match the new behaviour
5. Update the relevant table above (Boundary A, B, or C)
6. Add a **"Contract Change"** section to the PR description

### What Counts as a Breaking Change

- Changing the return type of any method in Boundaries A or B
- Renaming a hash key in the return value (e.g., `"run_list"` → `"runList"`)
- Changing `extract_nested_value` to raise instead of returning nil on missing paths

Breaking changes must be called out in the PR description and CHANGELOG.
