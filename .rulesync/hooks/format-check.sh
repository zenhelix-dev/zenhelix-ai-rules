#!/usr/bin/env bash

INPUT=$(cat)

FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
if [[ -z "$FILE_PATH" ]]; then
  exit 0
fi

case "$FILE_PATH" in
  *.kt|*.kts|*.java) ;;
  *) exit 0 ;;
esac

find_project_root() {
  local dir="$1"
  while [[ "$dir" != "/" ]]; do
    if [[ -f "$dir/build.gradle.kts" ]]; then
      echo "$dir"
      return 0
    fi
    dir=$(dirname "$dir")
  done
  return 1
}

PROJECT_ROOT=$(find_project_root "$(dirname "$FILE_PATH")") || exit 0
GRADLEW="$PROJECT_ROOT/gradlew"

if [[ ! -x "$GRADLEW" ]]; then
  exit 0
fi

BUILD_FILE="$PROJECT_ROOT/build.gradle.kts"

if grep -q "spotless" "$BUILD_FILE" 2>/dev/null; then
  (cd "$PROJECT_ROOT" && ./gradlew spotlessApply --quiet 2>/dev/null) || true
elif grep -q "ktlint" "$BUILD_FILE" 2>/dev/null; then
  (cd "$PROJECT_ROOT" && ./gradlew ktlintFormat --quiet 2>/dev/null) || true
fi

exit 0
