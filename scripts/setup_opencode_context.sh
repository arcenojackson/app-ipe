#!/usr/bin/env bash
set -euo pipefail

# Simple helper to print the OpenCode context summary file to stdout.
# Intended to be used to feed the system prompt for new OpenCode sessions.

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
CTX_FILE="$ROOT_DIR/OPENCODE_CONTEXT.md"

if [[ -f "$CTX_FILE" ]]; then
  echo "# OpenCode Context Snapshot"
  cat "$CTX_FILE"
  exit 0
else
  echo "OpenCode context file not found: $CTX_FILE" >&2
  exit 1
fi
