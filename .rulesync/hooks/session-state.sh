#!/usr/bin/env bash
set -euo pipefail

# Stop hook: save session context for resumption.
# Non-blocking. Always exits 0.

STATE_DIR=".claude/session-state"
STATE_FILE="${STATE_DIR}/last-session.md"

# Ensure directory exists
mkdir -p "$STATE_DIR"

TIMESTAMP="$(date '+%Y-%m-%d %H:%M:%S')"
BRANCH="$(git branch --show-current 2>/dev/null || echo "unknown")"
MODIFIED="$(git diff --name-only 2>/dev/null || true)"
STAGED="$(git diff --cached --name-only 2>/dev/null || true)"
RECENT_COMMITS="$(git log --oneline -5 2>/dev/null || true)"

cat > "$STATE_FILE" <<EOF
# Last Session State

- **Timestamp**: $TIMESTAMP
- **Branch**: $BRANCH

## Modified files (unstaged)

${MODIFIED:-_none_}

## Staged files

${STAGED:-_none_}

## Last 5 commits

${RECENT_COMMITS:-_none_}
EOF

echo "Session state saved to $STATE_FILE."

exit 0
