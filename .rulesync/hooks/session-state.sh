#!/usr/bin/env bash

INPUT=$(cat 2>/dev/null || true)

ROOT_DIR="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
STATE_DIR="${ROOT_DIR}/.claude/session-state"
STATE_FILE="${STATE_DIR}/last-session.md"

mkdir -p "$STATE_DIR" 2>/dev/null || true

TIMESTAMP="$(date '+%Y-%m-%d %H:%M:%S')"
BRANCH="$(git branch --show-current 2>/dev/null || echo "unknown")"
MODIFIED="$(git diff --name-only 2>/dev/null || true)"
STAGED="$(git diff --cached --name-only 2>/dev/null || true)"
RECENT_COMMITS="$(git log --oneline -5 2>/dev/null || true)"

{
  printf '%s\n' "# Last Session State"
  printf '%s\n' ""
  printf '%s\n' "- **Timestamp**: ${TIMESTAMP}"
  printf '%s\n' "- **Branch**: ${BRANCH}"
  printf '%s\n' ""
  printf '%s\n' "## Modified files (unstaged)"
  printf '%s\n' ""
  printf '%s\n' "${MODIFIED:-_none_}"
  printf '%s\n' ""
  printf '%s\n' "## Staged files"
  printf '%s\n' ""
  printf '%s\n' "${STAGED:-_none_}"
  printf '%s\n' ""
  printf '%s\n' "## Last 5 commits"
  printf '%s\n' ""
  printf '%s\n' "${RECENT_COMMITS:-_none_}"
} > "$STATE_FILE" 2>/dev/null || true

echo "Session state saved to $STATE_FILE." >&2

exit 0
