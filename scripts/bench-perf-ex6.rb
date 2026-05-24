# frozen_string_literal: true
#
# bench-perf-ex6.rb — Benchmark script for Run Ex6 Performance Touch-point
#
# Usage:
#   ruby scripts/bench-perf-ex6.rb          # run both benchmarks
#
# Run BEFORE applying code changes to capture baseline, then run AFTER.
# No external gems required — uses Ruby stdlib Benchmark only.
#
require "benchmark"

ITERATIONS = 100_000

# ---------------------------------------------------------------------------
# Benchmark 1: flat_map vs map! + flatten!
# Models category_words.map! { |w| w.split("-") }.flatten! in the command loaders.
# ---------------------------------------------------------------------------
puts "=" * 60
puts "Benchmark 1: flat_map vs map! + flatten!"
puts "Input: array of hyphenated command words, #{ITERATIONS} iterations"
puts "=" * 60

SAMPLE_WORDS = %w[node-run-list-add knife-bootstrap ssh-key-generate].freeze

Benchmark.bmbm(30) do |x|
  x.report("map! + flatten! (before):") do
    ITERATIONS.times do
      words = SAMPLE_WORDS.dup
      words.map! { |w| w.split("-") }.flatten!
      words
    end
  end

  x.report("flat_map       (after): ") do
    ITERATIONS.times do
      words = SAMPLE_WORDS.dup
      words = words.flat_map { |w| w.split("-") }
      words
    end
  end
end

puts

# ---------------------------------------------------------------------------
# Benchmark 2: << in-place append vs + string concatenation
# Models parts.inject("") { |acc, part| acc + part.read } in streaming uploader.
# ---------------------------------------------------------------------------
puts "=" * 60
puts "Benchmark 2: << in-place append vs + string concat"
puts "Input: 50 StringIO parts of 512 bytes each, #{ITERATIONS / 100} iterations"
puts "=" * 60

require "stringio"

PART_COUNT  = 50
PART_SIZE   = 512
PART_DATA   = ("x" * PART_SIZE).freeze

def make_parts
  Array.new(PART_COUNT) { StringIO.new(PART_DATA.dup) }
end

Benchmark.bmbm(30) do |x|
  x.report("inject + concat (before):") do
    (ITERATIONS / 100).times do
      parts = make_parts
      parts.inject("") { |acc, part| acc + part.read }
    end
  end

  x.report("each_with_object << (after):") do
    (ITERATIONS / 100).times do
      parts = make_parts
      parts.each_with_object(+"") { |part, acc| acc << part.read }
    end
  end
end

puts
puts "Done. Record the real/user times above as BEFORE or AFTER evidence."
