#!/usr/bin/env bash
# scripts/run-tests.sh
# Reusable local test script for knife development.
# Mirrors what CI runs so results are reproducible locally.
#
# Usage:
#   ./scripts/run-tests.sh            # run full suite
#   ./scripts/run-tests.sh unit       # run unit tests only
#   ./scripts/run-tests.sh spec/unit/knife/status_spec.rb  # run one file

set -euo pipefail

SUITE="${1:-all}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

export CHEF_LICENSE="accept-no-persist"
export FORCE_FFI_YAJL="ext"

echo "==> Installing dependencies..."
bundle install --quiet

echo "==> Creating test node fixtures..."
mkdir -p spec/data/nodes
touch spec/data/nodes/test.rb spec/data/nodes/default.rb spec/data/nodes/test.example.com.rb

case "$SUITE" in
  unit)
    echo "==> Running unit tests..."
    bundle exec rspec spec/unit/ --format progress
    ;;
  functional)
    echo "==> Running functional tests..."
    bundle exec rspec spec/functional/ --format progress
    ;;
  all)
    echo "==> Running full test suite (rake spec)..."
    bundle exec rake spec
    ;;
  *)
    echo "==> Running: bundle exec rspec $SUITE"
    bundle exec rspec "$SUITE" --format documentation
    ;;
esac

echo ""
echo "==> Done. All checks passed."
