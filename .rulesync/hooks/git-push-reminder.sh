#!/usr/bin/env bash

INPUT="$(cat 2>/dev/null || true)"

COMMAND="$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null || true)"

if echo "$COMMAND" | grep -q "git push" 2>/dev/null; then
  echo "Warning: About to git push. Verify: quality gates passed, changes reviewed, correct branch." >&2
fi

exit 0
