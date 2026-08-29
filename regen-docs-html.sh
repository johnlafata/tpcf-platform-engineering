#!/usr/bin/env bash
# Regenerate the .html companion next to every .md file in this repo, so
# docs are readable by double-clicking (opens in the default browser) on
# machines with no Markdown-aware application associated with .md files.
# Markdown stays the source of truth -- re-run this after editing any .md
# file. Pure Python standard library, no pip installs required.
#
# Usage: ./regen-docs-html.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if command -v python3 >/dev/null 2>&1; then
    PYTHON_CMD=python3
elif command -v python >/dev/null 2>&1; then
    PYTHON_CMD=python
else
    echo "Error: python3 (or python) is required and was not found on PATH." >&2
    exit 1
fi

"$PYTHON_CMD" "$SCRIPT_DIR/regen-docs-html.py" "$SCRIPT_DIR"
