#!/usr/bin/env bash

INPUT=$(cat 2>/dev/null || true)

LOG_DIR="${HOME}/.claude"
LOG_FILE="${LOG_DIR}/cost-tracker.log"

mkdir -p "$LOG_DIR" 2>/dev/null || true
touch "$LOG_FILE" 2>/dev/null || true

TIMESTAMP="$(date '+%Y-%m-%d %H:%M:%S')"

FILES_CHANGED="$(git diff --name-only 2>/dev/null | wc -l | tr -d ' ')"

echo "[$TIMESTAMP] files_changed=$FILES_CHANGED" >> "$LOG_FILE" 2>/dev/null || true

echo "Session ended at $TIMESTAMP. Files changed: $FILES_CHANGED. Logged to $LOG_FILE." >&2

exit 0
