#!/usr/bin/env bash
# scripts/gen-architecture.sh
#
# Repeatable architecture diagram refresh helper.
#
# What it does:
#   1. Introspects lib/chef/knife/ to count subcommands and core utilities
#   2. Compares node counts against the current .mmd file
#   3. Prints a change summary showing what shifted
#   4. Reminds maintainers which sections to update manually
#
# Usage:
#   bash scripts/gen-architecture.sh
#
# When to run:
#   - After adding/removing files in lib/chef/knife/ or lib/chef/knife/core/
#   - As part of a PR that touches the architecture
#   - The mermaid-lint CI workflow calls this automatically
#
# Rollback: this script is read-only — it never writes to architecture.mmd.
#   To revert a diagram change: git checkout HEAD~1 -- ai-track-docs/architecture.mmd

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MMD_FILE="$REPO_ROOT/ai-track-docs/architecture.mmd"
KNIFE_DIR="$REPO_ROOT/lib/chef/knife"
CORE_DIR="$KNIFE_DIR/core"

echo "=========================================="
echo " Architecture Change Summary"
echo " $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
echo "=========================================="
echo ""

# --- Codebase state ---
SUBCOMMAND_COUNT=$(find "$KNIFE_DIR" -maxdepth 1 -name "*.rb" | wc -l | tr -d ' ')
CORE_COUNT=$(find "$CORE_DIR" -maxdepth 1 -name "*.rb" | wc -l | tr -d ' ')

echo "## Codebase"
echo "  Subcommands (lib/chef/knife/*.rb):      $SUBCOMMAND_COUNT files"
echo "  Core utilities (lib/chef/knife/core/):  $CORE_COUNT files"
echo ""

# --- Diagram state ---
MMD_NODES=$(grep -cE '^\s+[A-Z_]+\[' "$MMD_FILE" || true)
MMD_EDGES=$(grep -cE '\s+-->' "$MMD_FILE" || true)
MMD_LINES=$(wc -l < "$MMD_FILE" | tr -d ' ')

echo "## Diagram (ai-track-docs/architecture.mmd)"
echo "  Lines:  $MMD_LINES"
echo "  Nodes:  $MMD_NODES"
echo "  Edges:  $MMD_EDGES"
echo ""

# --- Core utilities listed in diagram ---
echo "## Core utilities currently in diagram"
grep -oE 'core/[a-z_]+\.rb' "$MMD_FILE" | sort -u | while read -r f; do
  echo "  $f"
done
echo ""

# --- Core utilities on disk not yet in diagram ---
echo "## Core utilities on disk (check if diagram is current)"
MISSING=0
while IFS= read -r filepath; do
  basename_rb="core/$(basename "$filepath")"
  if ! grep -q "$basename_rb" "$MMD_FILE"; then
    echo "  !! MISSING from diagram: $basename_rb"
    MISSING=$((MISSING + 1))
  else
    echo "  OK: $basename_rb"
  fi
done < <(find "$CORE_DIR" -maxdepth 1 -name "*.rb" | sort)
echo ""

# --- Summary ---
if [ "$MISSING" -gt 0 ]; then
  echo "## ⚠️  Action required"
  echo "  $MISSING core file(s) are not represented in architecture.mmd."
  echo "  Add a node to the CoreUtils subgraph and an edge where appropriate."
  echo "  Then re-run this script to verify."
else
  echo "## ✅ Diagram appears current"
  echo "  All core utilities are represented in architecture.mmd."
fi

echo ""
echo "## How to update the diagram"
echo "  1. Open ai-track-docs/architecture.mmd"
echo "  2. Add new nodes under the appropriate subgraph"
echo "  3. Add edges showing data flow"
echo "  4. Re-run: bash scripts/gen-architecture.sh"
echo "  5. Validate: mmdc -i ai-track-docs/architecture.mmd -o /tmp/arch.svg"
echo ""
echo "=========================================="
