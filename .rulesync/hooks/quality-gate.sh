#!/usr/bin/env bash
set -euo pipefail

# Post-tool-use hook: run static analysis (detekt/checkstyle/spotbugs) after editing JVM source files.
# Idempotent, non-blocking. Always exits 0.

FILE_PATH="${CLAUDE_FILE_PATH:-}"

# Skip if no file path provided
if [[ -z "$FILE_PATH" ]]; then
  exit 0
fi

# Only process JVM source files
case "$FILE_PATH" in
  *.kt|*.kts) FILE_TYPE="kotlin" ;;
  *.java)     FILE_TYPE="java" ;;
  *)          exit 0 ;;
esac

# Require gradlew
if [[ ! -x "./gradlew" ]]; then
  exit 0
fi

BUILD_FILE="build.gradle.kts"

if [[ "$FILE_TYPE" == "kotlin" ]]; then
  if grep -q "detekt" "$BUILD_FILE" 2>/dev/null; then
    ./gradlew detektMain --quiet 2>/dev/null || true
  fi
elif [[ "$FILE_TYPE" == "java" ]]; then
  if grep -q "checkstyle" "$BUILD_FILE" 2>/dev/null; then
    ./gradlew checkstyleMain --quiet 2>/dev/null || true
  fi
  if grep -q "spotbugs" "$BUILD_FILE" 2>/dev/null; then
    ./gradlew spotbugsMain --quiet 2>/dev/null || true
  fi
fi

exit 0
