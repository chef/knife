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
