#!/usr/bin/env bash
set -euo pipefail

# Stop hook: track session metrics to a persistent log file.
# Non-blocking. Always exits 0.

LOG_DIR="${HOME}/.claude"
LOG_FILE="${LOG_DIR}/cost-tracker.log"

# Ensure log directory and file exist
mkdir -p "$LOG_DIR"
touch "$LOG_FILE"

TIMESTAMP="$(date '+%Y-%m-%d %H:%M:%S')"

# Count changed files via git
FILES_CHANGED="$(git diff --stat 2>/dev/null | tail -1 | grep -oE '[0-9]+ file' | grep -oE '[0-9]+' || echo "0")"

# Append entry
echo "[$TIMESTAMP] files_changed=$FILES_CHANGED" >> "$LOG_FILE"

# Print brief summary
echo "Session ended at $TIMESTAMP. Files changed: $FILES_CHANGED. Logged to $LOG_FILE."

exit 0
