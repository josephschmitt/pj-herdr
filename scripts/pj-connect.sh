#!/usr/bin/env bash
set -euo pipefail

FORCE_NEW=false
if [ "${1:-}" = "--new" ]; then
  FORCE_NEW=true
  shift
fi

PROJECT_PATH="${1:?pj-connect.sh: PROJECT_PATH is required}"
PROJECT_NAME="$(basename "$PROJECT_PATH" | tr '.:' '_')"
HERDR="${HERDR_BIN_PATH:-herdr}"

if [ "$FORCE_NEW" = true ]; then
  "$HERDR" workspace create --cwd "$PROJECT_PATH" --label "$PROJECT_NAME" --focus
  exit 0
fi

# Check if a workspace already exists for this path or name.
# Match by worktree.checkout_path (exact path) or label (basename match).
WORKSPACE_ID=$("$HERDR" workspace list | jq -r \
  --arg path "$PROJECT_PATH" \
  --arg name "$PROJECT_NAME" '
    .result.workspaces[]
    | select(
        (.worktree.checkout_path // "") == $path
        or .label == $name
      )
    | .workspace_id
  ' | head -1)

if [ -n "$WORKSPACE_ID" ]; then
  "$HERDR" workspace focus "$WORKSPACE_ID"
else
  "$HERDR" workspace create --cwd "$PROJECT_PATH" --label "$PROJECT_NAME" --focus
fi
