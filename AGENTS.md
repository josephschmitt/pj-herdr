# pj-herdr — Agent Coding Guidelines

## What this project is

`pj-herdr` is a [herdr](https://herdr.dev) plugin that bridges [pj](https://github.com/nickel-org/pj) (project jumper) with herdr workspaces. Pressing `Ctrl-s O` opens an overlay pane with a fuzzy project picker; selecting a project creates or switches to its herdr workspace.

## File structure

```
herdr-plugin.toml          Plugin manifest: panes, actions, keybindings
cable/pj-herdr.toml        Television cable channel (picker=tv only)
scripts/pj-picker.sh       Launcher: reads config, dispatches to tv or fzf
scripts/pj-connect.sh      Create-or-switch workspace logic (shared by both pickers)
AGENTS.md                  This file
CLAUDE.md -> AGENTS.md     Symlink (Claude Code convention)
README.md                  User-facing docs and install instructions
```

## Component responsibilities

### `herdr-plugin.toml`
Declares the plugin to herdr. Key fields:
- `[[panes]]` — defines the `picker` overlay pane; herdr runs `pj-picker.sh` inside it
- `[[actions]]` — `open-picker` action that opens the overlay pane
- `[[keys.command]]` — binds `prefix+O` to `pj.open-picker`

Env vars herdr injects when running the pane:
- `$HERDR_PLUGIN_ROOT` — absolute path to the plugin directory (this repo)
- `$HERDR_PLUGIN_CONFIG_DIR` — user's config dir for this plugin (where `config` lives)
- `$HERDR_BIN_PATH` — path to the `herdr` binary

### `scripts/pj-picker.sh`
1. Reads `$HERDR_PLUGIN_CONFIG_DIR/config` for `picker=tv|fzf|auto`
2. If `auto`: uses `tv` if installed, else `fzf`
3. **TV path**: runs `tv pj-herdr` — TV loads the cable channel, which has its own keybindings and actions
4. **fzf path**: runs `pj | fzf` with `--expect` to capture key presses, then dispatches to `pj-connect.sh` or runs herdr/editor commands directly

### `cable/pj-herdr.toml`
TV cable channel — only used when `picker=tv`. Modeled on the existing `pj.toml` but with herdr-specific actions:
- `enter` → `connect` (switch to or create workspace)
- `ctrl-o` → `new_workspace` (always create new)
- `ctrl-e` → `edit` (open in `$EDITOR`)
- `ctrl-n` → `new_tab` (herdr tab create)
- `ctrl-r` → `clear_cache` + reload source

### `scripts/pj-connect.sh`
Shared workspace logic:
- Without `--new`: lists workspaces, matches by `worktree.checkout_path` or `label`, focuses if found, creates otherwise
- With `--new`: always creates a new workspace

## Keybindings (both pickers)

| Key | Action |
|-----|--------|
| Enter | Connect: switch to existing workspace, or create one |
| Ctrl-n | New workspace: always create (even if one exists) |
| Ctrl-e | Edit: open project in `$EDITOR` |
| Ctrl-t | New tab: `herdr tab create --cwd <path> --focus` |
| Ctrl-r | Clear pj cache and reload list |

## Config file

Location: `$HERDR_PLUGIN_CONFIG_DIR/config` (plain key=value, no section headers)

```
picker=tv
```

Valid values: `tv`, `fzf`, `auto` (default — prefers tv if installed, falls back to fzf).

## Dependencies

| Dependency | Required | Used by |
|-----------|----------|---------|
| `pj` | Yes | Source of project list |
| `tv` | One of tv/fzf | TV picker backend |
| `fzf` | One of tv/fzf | fzf picker backend |
| `jq` | Yes | Parse `herdr workspace list` JSON |
| `eza` | No | Tree preview (fzf preview falls back to `tree`, then `ls -la`) |

## Testing changes

```bash
# Link plugin for local development (run once)
herdr plugin link ~/development/pj-herdr

# Symlink TV cable channel (run once, only needed for picker=tv)
ln -sf ~/development/pj-herdr/cable/pj-herdr.toml ~/.config/television/cable/pj-herdr.toml

# Make scripts executable (run once)
chmod +x ~/development/pj-herdr/scripts/*.sh

# After editing herdr-plugin.toml, reload config
herdr server reload-config

# Set picker preference (optional)
mkdir -p "$(herdr plugin config-dir pj)"
echo "picker=fzf" > "$(herdr plugin config-dir pj)/config"

# Verify plugin is registered
herdr plugin list

# Trigger the picker
# Press Ctrl-s O inside herdr
```

## Herdr plugin API reference

See https://herdr.dev/docs/plugins/ for the full plugin manifest spec.

Key `herdr` CLI commands used by this plugin:
- `herdr workspace list` — JSON list of workspaces (used by pj-connect.sh)
- `herdr workspace create --cwd <path> --label <name> --focus`
- `herdr workspace focus <workspace_id>`
- `herdr tab create --cwd <path> --focus`
- `herdr plugin pane open --plugin pj --entrypoint picker`

## Open questions / known risks

1. **`$HERDR_PLUGIN_ROOT` in TV actions**: TV spawns child processes for actions; need to verify the env var propagates. Fallback: hardcode the script path or put `pj-connect.sh` on `$PATH`.
2. **fzf preview without eza**: The fzf preview falls back to `tree` then `ls -la` automatically — no action needed.
