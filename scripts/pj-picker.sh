#!/usr/bin/env bash
set -euo pipefail

PLUGIN_ROOT="${HERDR_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
CONFIG_DIR="${HERDR_PLUGIN_CONFIG_DIR:-$PLUGIN_ROOT}"
CONFIG_FILE="$CONFIG_DIR/config"
CONNECT_SCRIPT="$PLUGIN_ROOT/scripts/pj-connect.sh"

# --- helpers -----------------------------------------------------------------

cfg() {
  # cfg KEY DEFAULT — read a value from the config file, fall back to DEFAULT
  local key="$1" default="$2"
  if [ -f "$CONFIG_FILE" ]; then
    local val
    val=$(grep -E "^${key}=" "$CONFIG_FILE" 2>/dev/null | cut -d= -f2 | tr -d ' "'"'" || true)
    [ -n "$val" ] && { echo "$val"; return; }
  fi
  echo "$default"
}

cfg_bool() {
  # cfg_bool KEY DEFAULT — returns "true" or "false"
  local val
  val=$(cfg "$1" "$2")
  case "$val" in
    true|yes|1) echo "true" ;;
    *)          echo "false" ;;
  esac
}

# --- read config -------------------------------------------------------------

PICKER=$(cfg picker auto)

SORT=$(cfg sort alpha)
SORT_DIRECTION=$(cfg sort_direction "")   # empty = let pj use its default
ICONS=$(cfg_bool icons true)
ANSI=$(cfg_bool ansi true)
WORKTREES=$(cfg worktrees auto)           # auto|yes|no
MAX_DEPTH=$(cfg max_depth "")
NO_NESTED=$(cfg_bool no_nested false)

# --- build pj flags ----------------------------------------------------------

PJ_FLAGS="--shorten --sort $SORT"
[ -n "$SORT_DIRECTION" ]      && PJ_FLAGS="$PJ_FLAGS --sort-direction $SORT_DIRECTION"
[ "$ICONS" = "true" ]         && PJ_FLAGS="$PJ_FLAGS --icons"
[ "$ANSI" = "true" ]          && PJ_FLAGS="$PJ_FLAGS --ansi"
[ -n "$MAX_DEPTH" ]           && PJ_FLAGS="$PJ_FLAGS --max-depth $MAX_DEPTH"
[ "$NO_NESTED" = "true" ]     && PJ_FLAGS="$PJ_FLAGS --no-nested"
case "$WORKTREES" in
  yes) PJ_FLAGS="$PJ_FLAGS --worktrees" ;;
  no)  PJ_FLAGS="$PJ_FLAGS --no-worktrees" ;;
esac

PJ_CMD="pj $PJ_FLAGS"

# --- auto-detect picker ------------------------------------------------------

die() {
  echo "pj-herdr error: $*" >&2
  echo "Press any key to close..." >&2
  read -r -n1
  exit 1
}

if [ "$PICKER" = "auto" ]; then
  if command -v tv &>/dev/null; then
    PICKER="tv"
  elif command -v fzf &>/dev/null; then
    PICKER="fzf"
  else
    die "no picker found. Install tv or fzf, or set picker= in $CONFIG_FILE"
  fi
fi

# --- validate picker is installed --------------------------------------------

case "$PICKER" in
  tv)  command -v tv  &>/dev/null || die "picker=tv but 'tv' is not installed." ;;
  fzf) command -v fzf &>/dev/null || die "picker=fzf but 'fzf' is not installed." ;;
esac

# --- dispatch ----------------------------------------------------------------

case "$PICKER" in
  tv)
    # Launch tv as an ad-hoc channel so the pj command (including all config
    # flags) is built here rather than hardcoded in the cable TOML.
    # The cable channel supplies keybindings, preview, and actions.
    tv --cable-dir "$PLUGIN_ROOT/cable" \
       --source-command "$PJ_CMD" \
       pj-herdr \
      || true
    ;;

  fzf)
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

    RELOAD_CMD="pj --clear-cache >/dev/null 2>&1; $PJ_CMD"
    FZF_ANSI=""
    [ "$ANSI" = "true" ] && FZF_ANSI="--ansi"

    RESULT=$(eval "$PJ_CMD" \
      | fzf $FZF_ANSI \
            --reverse \
            --preview "$PREVIEW_CMD" \
            --preview-window=right:50% \
            --header "enter: open workspace  ctrl-n: new workspace  ctrl-w: worktree  ctrl-e: edit  ctrl-t: new tab  ctrl-r: clear cache" \
            --expect "ctrl-n,ctrl-w,ctrl-e,ctrl-t,ctrl-r" \
            --bind "ctrl-r:reload($RELOAD_CMD)" \
      || true)

    [ -z "$RESULT" ] && exit 0

    KEY=$(printf '%s' "$RESULT" | head -1)
    SELECTION=$(printf '%s' "$RESULT" | tail -1)

    # Strip icon prefix (everything up to and including first space), expand ~
    PROJECT_PATH=$(printf '%s' "$SELECTION" | sed 's/^[^ ]* //' | sed "s|^~|$HOME|")

    case "$KEY" in
      ctrl-n) "$CONNECT_SCRIPT" --new "$PROJECT_PATH" ;;
      ctrl-w) herdr worktree open --cwd "$PROJECT_PATH" --focus ;;
      ctrl-e) ${EDITOR:-vi} "$PROJECT_PATH" ;;
      ctrl-t) herdr tab create --cwd "$PROJECT_PATH" --focus ;;
      ctrl-r) ;; # handled inline by fzf --bind reload
      *)      "$CONNECT_SCRIPT" "$PROJECT_PATH" ;;
    esac
    ;;

  *)
    echo "Unknown picker: '$PICKER'. Set picker=tv, picker=fzf, or picker=auto in $CONFIG_FILE" >&2
    exit 1
    ;;
esac
