#!/usr/bin/env bash

INPUT=$(cat)

FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
if [[ -z "$FILE_PATH" ]]; then
  exit 0
fi

case "$FILE_PATH" in
  *.kt|*.kts) FILE_TYPE="kotlin" ;;
  *.java)     FILE_TYPE="java" ;;
  *)          exit 0 ;;
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

if [[ "$FILE_TYPE" == "kotlin" ]]; then
  if grep -q "detekt" "$BUILD_FILE" 2>/dev/null; then
    (cd "$PROJECT_ROOT" && ./gradlew detektMain --quiet 2>/dev/null) || true
  fi
elif [[ "$FILE_TYPE" == "java" ]]; then
  if grep -q "checkstyle" "$BUILD_FILE" 2>/dev/null; then
    (cd "$PROJECT_ROOT" && ./gradlew checkstyleMain --quiet 2>/dev/null) || true
  fi
  if grep -q "spotbugs" "$BUILD_FILE" 2>/dev/null; then
    (cd "$PROJECT_ROOT" && ./gradlew spotbugsMain --quiet 2>/dev/null) || true
  fi
fi

exit 0
