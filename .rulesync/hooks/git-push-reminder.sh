#!/usr/bin/env bash
set -euo pipefail

# Pre-tool-use hook: warn before git push commands.
# Advisory only, non-blocking. Always exits 0.

# Read tool input from stdin (Claude Code passes tool params via stdin for preToolUse hooks)
INPUT="$(cat 2>/dev/null || true)"

# Check if input contains a git push command
if echo "$INPUT" | grep -q "git push" 2>/dev/null; then
  echo "⚠ About to git push. Verify: quality gates passed, changes reviewed, correct branch." >&2
fi

exit 0
