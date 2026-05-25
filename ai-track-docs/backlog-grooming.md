# Run Ex12 — Backlog Grooming via Chat

**Level**: Run | **Exercise**: 12 | **Branch**: `learn/run/nikhil-ex12-backlog-grooming`

## Subsystem Analyzed

**`lib/chef/knife/core/`** — 16 files, ~2 400 LOC  
The knife core subsystem provides command loading, output formatting, node editing,
retry logic, and bootstrap context generation. This grooming session was conducted
by asking Copilot to audit the directory for quality, correctness, documentation,
and maintainability gaps.

---

## Backlog Items

### BI-01 — Handle malformed JSON in ObjectLoader

**Priority**: Medium | **Effort**: S (1–2 hours) | **Label**: `bug`, `good first issue`

| Field | Detail |
|-------|--------|
| **File** | `lib/chef/knife/core/object_loader.rb:88–103` (`object_from_file`) |
| **Problem** | `FFI_Yajl::Parser.parse(File.read(filename))` raises `FFI_Yajl::ParseError` on invalid JSON. The exception is unrescued, so operators see a raw Ruby stack trace instead of a friendly message. |
| **Acceptance criteria** | 1. Wrap `FFI_Yajl::Parser.parse` in a `rescue FFI_Yajl::ParseError` block. 2. Emit `ui.fatal("Could not parse JSON at #{filename}: #{e.message}")`. 3. Call `exit 30` (consistent with existing `.rb` parse error). 4. Unit test: mock `FFI_Yajl::Parser.parse` to raise `FFI_Yajl::ParseError` and assert `ui.fatal` is called. |
| **Code link** | `lib/chef/knife/core/object_loader.rb:95` — `FFI_Yajl::Parser.parse(...)` |

---

### BI-02 — Resolve 2009 TODO comments in CookbookSiteStreamingUploader

**Priority**: Low | **Effort**: XS (30 min) | **Label**: `tech-debt`, `good first issue`

| Field | Detail |
|-------|--------|
| **File** | `lib/chef/knife/core/cookbook_site_streaming_uploader.rb:118` and `:152` |
| **Problem** | Two `TODO` comments left since 2009 describe known workarounds. Line 118 asks for unified body hashing (a design improvement). Line 152 annotates a response class monkey-patch with `# TODO: stop the following madness!` — neither has been addressed in 15 years. |
| **Acceptance criteria** | 1. For line 118: replace `TODO:` with `NOTE:` explaining that body hashing uses expanded multipart text intentionally, linking to any relevant RFC/doc. 2. For line 152: replace `TODO:` with `NOTE:` explaining the monkey-patch is intentional for test compatibility, or extract to a named class/module. 3. No `TODO:` or `FIXME:` comments remain in this file. |
| **Code link** | `lib/chef/knife/core/cookbook_site_streaming_uploader.rb:118`, `:152` |

---

### BI-03 — Extract helpers from `bootstrap_context.rb#config_content`

**Priority**: Medium | **Effort**: M (2–4 hours) | **Label**: `refactor`

| Field | Detail |
|-------|--------|
| **File** | `lib/chef/knife/core/bootstrap_context.rb:92` (`config_content`) |
| **Problem** | `config_content` is 70+ lines, building a multi-section chef client config string. This exceeds the 20-line complexity guideline and makes individual sections hard to test or override. |
| **Acceptance criteria** | 1. Refactor into 3–4 private helper methods (e.g. `log_config_section`, `ssl_config_section`, `proxy_config_section`). 2. `config_content` body ≤ 20 lines — delegates to helpers. 3. All existing unit tests pass unchanged. 4. New unit tests for at least 2 helper methods. |
| **Code link** | `lib/chef/knife/core/bootstrap_context.rb:92` |

---

### BI-04 — Add YARD documentation to ObjectLoader public methods

**Priority**: Low | **Effort**: XS (30 min) | **Label**: `documentation`, `good first issue`

| Field | Detail |
|-------|--------|
| **File** | `lib/chef/knife/core/object_loader.rb` |
| **Problem** | Five public methods (`load_from`, `find_file`, `find_all_objects`, `find_all_object_dirs`, `object_from_file`) have no `@param`, `@return`, or `@api` tags. Operators extending or testing against ObjectLoader have no machine-readable API contract. |
| **Acceptance criteria** | 1. All 5 public methods have `@param` with type and description. 2. All 5 have `@return` with type. 3. All 5 have `@api public`. 4. `initialize` has `@param` for `klass` and `ui`. 5. Passes YARD lint (`bundle exec yard stats --no-output`). |
| **Code link** | `lib/chef/knife/core/object_loader.rb:37–116` |

---

### BI-05 — Allow callers to extend RetryWithBackoff exception list

**Priority**: Low | **Effort**: S (1 hour) | **Label**: `enhancement`

| Field | Detail |
|-------|--------|
| **File** | `lib/chef/knife/core/retry_with_backoff.rb:52` (`with_retries`) |
| **Problem** | `RETRYABLE_ERRORS` is a frozen constant. Knife commands that need to retry domain-specific Chef server exceptions (e.g. `Chef::Exceptions::ConnectionRefused`) cannot extend the list without duplicating logic. The current `retryable:` kwarg accepts a full list but callers must know and replicate all 4 base classes. |
| **Acceptance criteria** | 1. Add `extra_retryable: []` keyword argument to `with_retries`. 2. Merge `retryable + extra_retryable` before the `rescue` clause. 3. Default behavior unchanged when `extra_retryable` is omitted. 4. Unit test: verify that a custom exception class passed via `extra_retryable:` triggers a retry. 5. YARD docs updated. |
| **Code link** | `lib/chef/knife/core/retry_with_backoff.rb:52` |

---

## Priority Order

| Rank | Item | Rationale |
|------|------|-----------|
| 1 | BI-01 | User-facing bug — raw stack trace on bad JSON |
| 2 | BI-03 | Maintainability blocker — 70-line method hard to test |
| 3 | BI-05 | Enables reuse across all HTTP knife commands |
| 4 | BI-02 | Cleans up 15-year-old tech debt |
| 5 | BI-04 | API documentation quality |

**Good first tasks** (suitable for agent or new contributor delegation): BI-02, BI-04

---

## Simulated Patch Plan: BI-01

### Delegation Prompt

```
You are working on lib/chef/knife/core/object_loader.rb.

In the `object_from_file` method (line 95), the call
`FFI_Yajl::Parser.parse(File.read(filename))` can raise
`FFI_Yajl::ParseError` if the file contains invalid JSON.
Currently this exception is unrescued, producing a raw stack trace.

Please:
1. Wrap the FFI_Yajl::Parser.parse call in a begin/rescue block
2. Rescue FFI_Yajl::ParseError
3. Call ui.fatal("Could not parse JSON at #{filename}: #{e.message}")
4. Call exit 30 (consistent with existing parse error exit code)

Constraints:
- Do not change behavior for valid JSON files
- Do not rescue any other exception classes
- Keep the existing Chef::Log.trace call before the rescue block
```

### Expected Diff Sketch

```diff
-            Chef::Log.trace("ObjectLoader: using JSON parser for #{filename}")
-            r = FFI_Yajl::Parser.parse(File.read(filename))
+            Chef::Log.trace("ObjectLoader: using JSON parser for #{filename}")
+            begin
+              r = FFI_Yajl::Parser.parse(File.read(filename))
+            rescue FFI_Yajl::ParseError => e
+              ui.fatal("Could not parse JSON at #{filename}: #{e.message}")
+              exit 30
+            end
```

### Test Expectations

```ruby
context "when the JSON file is malformed" do
  let(:data) { "node" }
  let(:repo_location) { "nodes" }

  it "calls ui.fatal with the filename and parse error message" do
    allow(FFI_Yajl::Parser).to receive(:parse).and_raise(
      FFI_Yajl::ParseError, "unexpected token"
    )
    allow(File).to receive(:read).and_return("{bad json")
    allow(File).to receive(:exist?).and_return(true)
    allow(File).to receive(:readable?).and_return(true)
    expect(loader.ui).to receive(:fatal).with(/Could not parse JSON/)
    expect { loader.object_from_file("/some/file.json") }.to raise_error(SystemExit)
  end
end
```

### Review Checklist for BI-01

- [ ] Does `rescue FFI_Yajl::ParseError` appear only where the parse call is?
- [ ] Is the exit code 30 (consistent with line 113)?
- [ ] Does the `ui.fatal` message include filename and error message?
- [ ] Does existing behavior for valid JSON remain unchanged?
- [ ] Is the new test isolated (mocks `FFI_Yajl::Parser.parse`)?

---

## How to Action These Items

```bash
# If you have GitHub Issues access:
gh issue create --title "BI-01: Handle malformed JSON in ObjectLoader" \
  --body "..." --label "bug,good first issue"

# Or reference this document in PRs targeting these files:
# ai-track-docs/backlog-grooming.md
```

---

## Rollback

This is a documentation-only commit. Rollback:

```bash
git revert HEAD
```
