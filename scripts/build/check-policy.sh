#!/usr/bin/env bash
set -euo pipefail

manifest="profiles/minimal-server/manifest.txt"

if [[ ! -f "$manifest" ]]; then
  echo "missing manifest: $manifest" >&2
  exit 1
fi

if grep -Eiq '(^|/)(x11|desktop|mate|gnome|kde)($|/)' "$manifest"; then
  echo "policy violation: desktop package class detected" >&2
  exit 2
fi

if grep -Eiq '(^|/)i386($|/)|(^|/)32($|/)' "$manifest"; then
  echo "policy warning: possible 32-bit runtime indicator detected" >&2
  exit 3
fi

echo "policy checks passed"
