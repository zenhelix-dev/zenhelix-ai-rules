#!/usr/bin/env bash

INPUT=$(cat 2>/dev/null || true)

COUNTER_FILE="/tmp/.claude-tool-calls-${PPID}-$(date +%Y%m%d)"

if [[ ! -f "$COUNTER_FILE" ]]; then
  echo "0" > "$COUNTER_FILE"
fi

COUNT="$(cat "$COUNTER_FILE" 2>/dev/null || echo "0")"
COUNT=$((COUNT + 1))
echo "$COUNT" > "$COUNTER_FILE"

if [[ "$COUNT" -ge 50 ]] && [[ $((COUNT % 25)) -eq 0 ]]; then
  echo "HINT: $COUNT tool calls this session. Consider /compact to free context." >&2
fi

exit 0
