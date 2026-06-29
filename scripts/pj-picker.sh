#!/usr/bin/env bash
set -euo pipefail

PLUGIN_ROOT="${HERDR_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
CONFIG_DIR="${HERDR_PLUGIN_CONFIG_DIR:-$PLUGIN_ROOT}"
CONFIG_FILE="$CONFIG_DIR/config"
CONNECT_SCRIPT="$PLUGIN_ROOT/scripts/pj-connect.sh"

# Read config — default to "auto" if not set
PICKER="auto"
if [ -f "$CONFIG_FILE" ]; then
  # Simple key=value config file
  PICKER=$(grep -E '^picker=' "$CONFIG_FILE" 2>/dev/null | cut -d= -f2 | tr -d ' "'"'" || echo "auto")
fi

if [ "$PICKER" = "auto" ]; then
  if command -v tv &>/dev/null; then
    PICKER="tv"
  else
    PICKER="fzf"
  fi
fi

case "$PICKER" in
  tv)
    # Television with the pj-herdr cable channel.
    # The channel handles all actions (connect, new_workspace, edit, new_tab, clear_cache).
    tv --cable-dir "$PLUGIN_ROOT/cable" pj-herdr
    ;;
  fzf)
    # fzf fallback — simpler but functional, same keybindings as the TV channel.
    PREVIEW_CMD='
      path=$(echo {} | sed "s/^[^ ]* //" | sed "s|^~|$HOME|")
      if command -v eza &>/dev/null; then
        eza --tree --color=always "$path"
      elif command -v tree &>/dev/null; then
        tree -C "$path"
      else
        ls -la "$path"
      fi
    '

    RESULT=$(pj --icons --ansi --shorten --sort alpha \
      | fzf --ansi \
            --reverse \
            --preview "$PREVIEW_CMD" \
            --preview-window=right:50% \
            --header "enter: open workspace  ctrl-n: new workspace  ctrl-e: edit  ctrl-t: new tab  ctrl-r: clear cache" \
            --expect "ctrl-n,ctrl-e,ctrl-t,ctrl-r" \
            --bind "ctrl-r:reload(pj --clear-cache >/dev/null 2>&1; pj --icons --ansi --shorten --sort alpha)" \
      || true)

    [ -z "$RESULT" ] && exit 0

    # fzf --expect outputs the key on line 1, selected entry on line 2
    KEY=$(printf '%s' "$RESULT" | head -1)
    SELECTION=$(printf '%s' "$RESULT" | tail -1)

    # Strip the icon prefix (everything up to and including the first space), expand ~
    PROJECT_PATH=$(printf '%s' "$SELECTION" | sed 's/^[^ ]* //' | sed "s|^~|$HOME|")

    case "$KEY" in
      ctrl-n)
        "$CONNECT_SCRIPT" --new "$PROJECT_PATH"
        ;;
      ctrl-e)
        ${EDITOR:-vi} "$PROJECT_PATH"
        ;;
      ctrl-t)
        herdr tab create --cwd "$PROJECT_PATH" --focus
        ;;
      ctrl-r)
        # ctrl-r is handled inline by fzf's --bind reload; nothing to do here
        ;;
      *)
        # Enter (or any unbound key) — connect/switch
        "$CONNECT_SCRIPT" "$PROJECT_PATH"
        ;;
    esac
    ;;
  *)
    echo "Unknown picker: '$PICKER'. Set picker=tv, picker=fzf, or picker=auto in $CONFIG_FILE" >&2
    exit 1
    ;;
esac
