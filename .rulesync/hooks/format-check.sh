#!/usr/bin/env bash

INPUT=$(cat 2>/dev/null || true)

FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
if [[ -z "$FILE_PATH" ]]; then
  exit 0
fi

case "$FILE_PATH" in
  *.kt|*.kts|*.java) ;;
  *) exit 0 ;;
esac

# --- Debounce: run every 5 edits ---
FORMAT_INTERVAL=5
SESSION_ID="${CLAUDE_SESSION_ID:-$(echo "$PWD" | md5sum 2>/dev/null | cut -c1-8 || echo "$PWD" | shasum | cut -c1-8)}"
COUNTER_FILE="/tmp/.claude-format-check-${SESSION_ID}-$(date +%Y%m%d)"

LOCK_DIR="$COUNTER_FILE.lock"
RUN_FORMAT=false
if mkdir "$LOCK_DIR" 2>/dev/null; then
  trap 'rmdir "$LOCK_DIR" 2>/dev/null' EXIT
  CURRENT="$(cat "$COUNTER_FILE" 2>/dev/null || echo "0")"
  COUNT=$((CURRENT + 1))
  if [[ $((COUNT % FORMAT_INTERVAL)) -eq 0 ]]; then
    RUN_FORMAT=true
  fi
  echo "$COUNT" > "$COUNTER_FILE"
  rmdir "$LOCK_DIR" 2>/dev/null
  trap - EXIT
fi

if [[ "$RUN_FORMAT" != "true" ]]; then
  exit 0
fi
# --- End debounce ---

find_gradlew() {
  local dir="$1"
  while [[ "$dir" != "/" ]]; do
    if [[ -x "$dir/gradlew" ]]; then
      echo "$dir"
      return 0
    fi
    dir=$(dirname "$dir")
  done
  return 1
}

find_gradle_root() {
  local dir="$1"
  while [[ "$dir" != "/" ]]; do
    if [[ -f "$dir/settings.gradle.kts" || -f "$dir/settings.gradle" ]]; then
      echo "$dir"
      return 0
    fi
    dir=$(dirname "$dir")
  done
  return 1
}

find_module_dir() {
  local dir="$1"
  local root="$2"
  while [[ "$dir" != "/" && "$dir" != "$(dirname "$root")" ]]; do
    if [[ -f "$dir/build.gradle.kts" || -f "$dir/build.gradle" ]]; then
      echo "$dir"
      return 0
    fi
    dir=$(dirname "$dir")
  done
  return 1
}

GRADLEW_DIR=$(find_gradlew "$(dirname "$FILE_PATH")") || exit 0
GRADLE_ROOT=$(find_gradle_root "$(dirname "$FILE_PATH")") || exit 0
MODULE_DIR=$(find_module_dir "$(dirname "$FILE_PATH")" "$GRADLE_ROOT") || exit 0

if [[ "$MODULE_DIR" == "$GRADLE_ROOT" ]]; then
  TASK_PREFIX=""
else
  REL_PATH="${MODULE_DIR#"$GRADLE_ROOT"/}"
  TASK_PREFIX=":${REL_PATH//\//:}:"
fi

if [[ "$GRADLE_ROOT" == "$GRADLEW_DIR" ]]; then
  GRADLE_OPTS=()
else
  GRADLE_OPTS=("-p" "$GRADLE_ROOT")
fi

TASKS=$("$GRADLEW_DIR/gradlew" "${GRADLE_OPTS[@]}" "${TASK_PREFIX}tasks" --all --quiet 2>/dev/null) || exit 0

if echo "$TASKS" | grep -q "spotlessApply"; then
  ("$GRADLEW_DIR/gradlew" "${GRADLE_OPTS[@]}" "${TASK_PREFIX}spotlessApply" --quiet 2>/dev/null) || true
elif echo "$TASKS" | grep -q "ktlintFormat"; then
  ("$GRADLEW_DIR/gradlew" "${GRADLE_OPTS[@]}" "${TASK_PREFIX}ktlintFormat" --quiet 2>/dev/null) || true
fi

exit 0
