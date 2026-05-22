# frozen_string_literal: true
# Loaded when COVERAGE=true env var is set (e.g., in CI advisory job).
if ENV["COVERAGE"]
  require "simplecov"

  SimpleCov.start do
    enable_coverage :branch
    add_filter "/spec/"
    add_filter "/vendor/"
    track_files "lib/**/*.rb"
  end
end
