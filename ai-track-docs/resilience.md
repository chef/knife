# Resilience — Ex15

## Improvement: Error Mapping in `knife status`

`knife status` queries the Chef Server via `Chef::Search::Query#search`. Previously, any network or server error produced an unhandled exception with a Ruby stack trace — confusing for operators and hard to script around.

**Ex15 adds a rescue block** that maps two failure modes to clear fatal messages and a clean `exit 1`:

| Error | Cause | Output |
|-------|-------|--------|
| `Net::HTTPServerException` | Chef Server returns 5xx | `FATAL: Chef Server returned an error: <message>` |
| `SocketError` | DNS failure / network unreachable | `FATAL: Cannot reach Chef Server: <message>` |

### Code Location

```ruby
# lib/chef/knife/status.rb — run method
begin
  q.search(:node, query, build_search_opts) { |node| all_nodes << node }
rescue Net::HTTPServerException => e
  ui.fatal("Chef Server returned an error: #{e.message}")
  exit 1
rescue SocketError => e
  ui.fatal("Cannot reach Chef Server: #{e.message}")
  exit 1
end
```

## Failure Tests

Two tests in `spec/unit/knife/status_spec.rb` under `"resilience: error mapping"`:

1. **HTTP 500** — stubs `Net::HTTPServerException`, expects `ui.fatal` + `SystemExit(1)`
2. **SocketError** — stubs `SocketError`, expects `ui.fatal` + `SystemExit(1)`

### Running Locally

```bash
bundle exec rspec spec/unit/knife/status_spec.rb -e "resilience"
# Expect: 2 examples, 0 failures

bundle exec rspec spec/unit/knife/status_spec.rb
# Expect: 23 examples, 0 failures
```

## Why Error Mapping (Not Retry)

`knife status` is a **read-only query** command. Retrying on 5xx risks masking persistent server issues and adds latency. The right behavior is to fail fast with a clear message so operators can investigate the server directly. Retry/backoff is appropriate for write operations or bootstrap flows (already present in `knife bootstrap`).

---

## Walk Ex15 — RetryWithBackoff Helper

### Approach

Walk Ex15 adds a general-purpose `RetryWithBackoff` module
(`lib/chef/knife/core/retry_with_backoff.rb`) and integrates it at two
external HTTP call sites. The helper uses **no new gem dependencies**
(pure Ruby + stdlib `net/http`).

### Integrated Call Sites

| File | Method | Rationale |
|------|--------|-----------|
| `lib/chef/knife/supermarket_show.rb` | `get_cookbook_data` | External unauthenticated GET to `supermarket.chef.io`; network blips are common |
| `lib/chef/knife/cookbook_list.rb` | `run` | Authenticated GET to Chef Server; transient timeouts should not surface as hard failures |

### Tuning Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `retries` | `3` | Number of additional attempts after the first (total = retries + 1) |
| `base_delay` | `1.0` s | Sleep before first retry; doubles each attempt (1s, 2s, 4s) |
| `retryable` | `[Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNRESET, Errno::ECONNREFUSED]` | Exception classes that trigger a retry |

Override at the call site:

```ruby
with_retries(retries: 1, base_delay: 0.5) { rest.get(endpoint) }
```

### Rollback Guidance

| Scope | Action |
|-------|--------|
| Disable retry for one call | Pass `retries: 0` to `with_retries` |
| Remove retry from a file | Delete `include RetryWithBackoff` and `require_relative "core/retry_with_backoff"` |
| Remove entirely | Revert the three files changed in this commit |

### Failure Tests

Three test files added:

- `spec/unit/knife/core/retry_with_backoff_spec.rb` — 10 unit tests covering
  success, retry+succeed, exponential backoff timing, exhaust+raise, non-retryable
  passthrough, warn logging, and `retries: 0`
- `spec/unit/knife/supermarket_show_spec.rb` — 8 tests including 4 resilience scenarios
- `spec/unit/knife/cookbook_list_spec.rb` — 4 resilience scenarios added to existing suite

### Running Locally

```bash
bundle exec rspec spec/unit/knife/core/retry_with_backoff_spec.rb \
  spec/unit/knife/supermarket_show_spec.rb \
  spec/unit/knife/cookbook_list_spec.rb
# Expected: 23 examples, 0 failures
```

---

## Run Ex15 — Expanded RetryWithBackoff Coverage

### Newly Protected Call Paths

Ex15 (Run phase) extends `RetryWithBackoff` to three additional call sites that previously
had no retry protection:

| Command | Call Site | Wrapped Call |
|---------|-----------|--------------|
| `CookbookShow` | `run` (1-arg version list) | `rest.get(api_endpoint)` |
| `DataBagCreate` | `run` | `rest.get("data/...")`, `rest.post("data", ...)`, `rest.post("data/<bag>", item)` |
| `CookbookDelete` | `available_versions`, `delete_request` | `rest.get("cookbooks/...")`, `rest.delete(path)` |

### Failure Behavior: Before / After

**Before**: A single transient `Net::OpenTimeout` surfaced immediately to the user as an
unhandled exception, requiring a full manual retry of the command.

**After**: Up to 3 automatic retries with exponential backoff (1 s, 2 s, 4 s). Sample log:
```
WARN: Chef::Knife::CookbookShow#with_retries: attempt 1/4 failed (Net::OpenTimeout: execution expired); retrying in 1.0s
```

### Tuning Parameters

| Parameter | Default | Override Example |
|-----------|---------|-----------------|
| `retries` | `3` | `with_retries(retries: 5) { ... }` |
| `base_delay` | `1.0` s | `with_retries(base_delay: 0.5) { ... }` |
| `retryable` | network timeouts + connection errors | `with_retries(retryable: RETRYABLE_ERRORS + [SocketError]) { ... }` |

### Rollback Path

```bash
git revert HEAD   # removes include + with_retries wrappers, restoring bare rest.* calls
```

Or per-call disable: `with_retries(retries: 0) { rest.get(endpoint) }`

### Escalation Steps

1. **Single transient failure** — handled automatically; check `WARN` in knife output
2. **Repeated retries** — Chef Server may be overloaded; check server health
3. **All retries exhausted** — run `curl https://<chef-server>/organizations/<org>/nodes` to verify connectivity
4. **`Errno::ECONNREFUSED`** — Chef Server process is down; escalate to ops team

### Failure Test Evidence

Run Ex15 adds `resilience: RetryWithBackoff` contexts to three spec files:

```bash
bundle exec rspec spec/unit/knife/cookbook_show_spec.rb \
               spec/unit/knife/data_bag_create_spec.rb \
               spec/unit/knife/cookbook_delete_spec.rb \
               --format documentation
# Expected: all resilience examples pass
```

Each context covers:
- Transient error → retry → success
- Exhaust all retries → re-raise
- Non-retryable error → immediate raise (no sleep)
