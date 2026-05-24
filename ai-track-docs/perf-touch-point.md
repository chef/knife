# Performance Touch-point — Run Ex6

## Scope

Target directory: `lib/chef/knife/core/`  
Benchmark script: `scripts/bench-perf-ex6.rb` (Ruby stdlib `Benchmark.bmbm`)  
Test run: `bundle exec rspec spec/unit/knife/core/` — **281 examples, 0 failures**

---

## Optimization 1 — `flat_map` vs `map! + flatten!`

### What changed
**Files**: `lib/chef/knife/core/hashed_command_loader.rb:39`,
`lib/chef/knife/core/subcommand_loader.rb:139`

```ruby
# BEFORE — two passes: mutating map then in-place flatten (creates intermediate array of arrays)
category_words.map! { |w| w.split("-") }.flatten!

# AFTER — single pass via flat_map (no intermediate array of arrays)
category_words.replace(category_words.flat_map { |w| w.split("-") })
```

### Why it is safe
`Array#flat_map { |e| e.split("-") }` produces the identical output as
`map! { ... }.flatten!` for one level of nesting. `replace` mutates the
original array reference so callers holding a reference to `category_words`
still see the updated content — same contract as the original in-place mutation.

### Before/after metrics (100 000 iterations, 4-element hyphenated word array)

| Measurement | Before (`map! + flatten!`) | After (`flat_map`) | Improvement |
|---|---|---|---|
| user time   | 0.1192 s | 0.0751 s | **~37% faster** |
| real time   | 0.1226 s | 0.0768 s | **~37% faster** |

---

## Optimization 2 — `<<` in-place append vs `+` string concat

### What changed
**File**: `lib/chef/knife/core/cookbook_site_streaming_uploader.rb:121`

```ruby
# BEFORE — allocates a new String object on every iteration (O(n) allocations)
content_body = parts.inject("") { |result, part| result + part.read(0, part.size) }

# AFTER — mutates a single String in place (O(1) allocations regardless of part count)
content_body = parts.each_with_object(+"") { |part, acc| acc << part.read(0, part.size) }
```

The `+""` unfrozen-string literal ensures the accumulator is mutable even
when `frozen_string_literal: true` is enabled in future.

### Why it is safe
`String#<<` and `String#+` produce the same final string value.
The difference is that `+` allocates a new String on every call while `<<`
mutates the receiver. `content_body` is a local variable used only once
(for signing), so no external references are affected.

### Before/after metrics (1 000 iterations, 50 parts × 512 bytes each)

| Measurement | Before (`inject + concat`) | After (`each_with_object <<`) | Improvement |
|---|---|---|---|
| user time   | 0.0380 s | 0.0134 s | **~65% faster** |
| real time   | 0.0387 s | 0.0134 s | **~65% faster** |

---

## Rollback

```bash
# Revert the single commit that contains both optimizations
git revert HEAD
```

Both changes are confined to three files with no cross-file dependencies.
Reverting restores the original `map!+flatten!` and `inject+concat` patterns.

---

## Update Process for Future Micro-optimizations

1. Identify hot paths using `ruby-prof` or `stackprof` (or benchmark with `Benchmark.bmbm`).
2. Confirm the optimization is behavior-preserving by running the target spec suite.
3. Capture before/after metrics using `scripts/bench-perf-ex6.rb` (extend as needed).
4. Update this document with new evidence rows.
5. All changes must have a corresponding rollback in the PR description.
