#!/usr/bin/env bash

INPUT=$(cat 2>/dev/null || true)

FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
if [[ -z "$FILE_PATH" ]]; then
  exit 0
fi

case "$FILE_PATH" in
  *.kt|*.kts) FILE_TYPE="kotlin" ;;
  *.java)     FILE_TYPE="java" ;;
  *)          exit 0 ;;
esac

# --- Debounce: run every 15 edits, not on every write ---
QUALITY_INTERVAL=15
SESSION_ID="${CLAUDE_SESSION_ID:-$(echo "$PWD" | md5sum 2>/dev/null | cut -c1-8 || echo "$PWD" | shasum | cut -c1-8)}"
COUNTER_FILE="/tmp/.claude-quality-gate-${SESSION_ID}-$(date +%Y%m%d)"

LOCK_DIR="$COUNTER_FILE.lock"
RUN_CHECK=false
if mkdir "$LOCK_DIR" 2>/dev/null; then
  trap 'rmdir "$LOCK_DIR" 2>/dev/null' EXIT
  CURRENT="$(cat "$COUNTER_FILE" 2>/dev/null || echo "0")"
  COUNT=$((CURRENT + 1))
  if [[ $((COUNT % QUALITY_INTERVAL)) -eq 0 ]]; then
    RUN_CHECK=true
  fi
  echo "$COUNT" > "$COUNTER_FILE"
  rmdir "$LOCK_DIR" 2>/dev/null
  trap - EXIT
fi

if [[ "$RUN_CHECK" != "true" ]]; then
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

run_check() {
  local task="$1"
  local label="$2"
  OUTPUT=$("$GRADLEW_DIR/gradlew" "${GRADLE_OPTS[@]}" "${TASK_PREFIX}${task}" 2>&1) || {
    echo "QUALITY: ${label} found issues (edit #${COUNT}):" >&2
    echo "$OUTPUT" | tail -20 >&2
  }
}

if [[ "$FILE_TYPE" == "kotlin" ]]; then
  if echo "$TASKS" | grep -q "detektMain"; then
    run_check "detektMain" "detekt"
  fi
elif [[ "$FILE_TYPE" == "java" ]]; then
  if echo "$TASKS" | grep -q "checkstyleMain"; then
    run_check "checkstyleMain" "checkstyle"
  fi
  if echo "$TASKS" | grep -q "spotbugsMain"; then
    run_check "spotbugsMain" "spotbugs"
  fi
fi

exit 0
