#!/usr/bin/env bash

{
  echo "=== Session Summary ==="
  echo ""

  echo "--- Unstaged changes ---"
  UNSTAGED=$(git diff --stat 2>/dev/null)
  echo "${UNSTAGED:-(no unstaged changes)}"
  echo ""

  echo "--- Staged changes ---"
  STAGED=$(git diff --cached --stat 2>/dev/null)
  echo "${STAGED:-(no staged changes)}"
  echo ""

  echo "--- Overall ---"
  SHORTSTAT=$(git diff --shortstat 2>/dev/null)
  CACHED_SHORTSTAT=$(git diff --cached --shortstat 2>/dev/null)
  if [[ -n "$SHORTSTAT" ]]; then
    echo "Unstaged: $SHORTSTAT"
  fi
  if [[ -n "$CACHED_SHORTSTAT" ]]; then
    echo "Staged:   $CACHED_SHORTSTAT"
  fi
  if [[ -z "$SHORTSTAT" && -z "$CACHED_SHORTSTAT" ]]; then
    echo "No changes detected."
  fi
} >&2

exit 0
