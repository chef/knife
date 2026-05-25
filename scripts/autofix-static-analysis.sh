#!/usr/bin/env bash
# scripts/autofix-static-analysis.sh
#
# Repeatable autofix script for lib/chef/knife/core/ static analysis.
# Applies all correctable RuboCop offenses in the target path.
#
# Usage:
#   bash scripts/autofix-static-analysis.sh [--dry-run]
#
# Options:
#   --dry-run   Show offenses without applying corrections
#
# Cops fixed by this script:
#   Style/ConditionalAssignment  — prefer ternary/return over if/else assignment
#   Style/StringConcatenation    — prefer interpolation over + concatenation
#   Style/GuardClause            — prefer guard clauses over nested conditionals
#   Style/FrozenStringLiteralComment — require # frozen_string_literal: true
#
# Suppressions (documented, not auto-fixed):
#   Metrics/MethodLength excluded for bootstrap_context.rb and
#   windows_bootstrap_context.rb — template generators; long by design.
#
# Rollback:
#   git checkout -- lib/chef/knife/core/
#
set -euo pipefail

TARGET="lib/chef/knife/core/"
COPS="Style/ConditionalAssignment,Style/StringConcatenation,Style/GuardClause,Style/FrozenStringLiteralComment"

if [[ "${1:-}" == "--dry-run" ]]; then
  echo "=== Dry run: showing offenses only (no changes applied) ==="
  bundle exec rubocop "$TARGET" --only "$COPS" --format progress
else
  echo "=== Applying auto-corrections to $TARGET ==="
  bundle exec rubocop "$TARGET" --only "$COPS" --autocorrect
  echo ""
  echo "=== Post-fix verification ==="
  bundle exec rubocop "$TARGET" --only "$COPS" --format progress
  echo ""
  echo "=== Running specs to confirm no regression ==="
  bundle exec rspec spec/unit/knife/core/ --format progress
fi
