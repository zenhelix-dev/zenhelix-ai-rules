#!/usr/bin/env bash
set -euo pipefail

# Pre-tool-use hook: suggest /compact after many tool calls to free context.
# Non-blocking. Always exits 0.

COUNTER_FILE="/tmp/.claude-tool-calls-$(date +%Y%m%d)"

# Initialize counter file if missing
if [[ ! -f "$COUNTER_FILE" ]]; then
  echo "0" > "$COUNTER_FILE"
fi

# Increment counter
COUNT="$(cat "$COUNTER_FILE" 2>/dev/null || echo "0")"
COUNT=$((COUNT + 1))
echo "$COUNT" > "$COUNTER_FILE"

# Suggest compact every 25 calls after reaching 50
if [[ "$COUNT" -ge 50 ]] && [[ $((COUNT % 25)) -eq 0 ]]; then
  echo "HINT: $COUNT tool calls today. Consider /compact to free context." >&2
fi

exit 0
