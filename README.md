# pj-herdr

A [herdr](https://herdr.dev) plugin that brings [pj](https://github.com/nickel-org/pj) project jumping to herdr workspaces.

Press `Ctrl-s O` → fuzzy-search your projects → hit Enter → herdr creates or switches to that project's workspace.

## How it works

- Opens an **overlay pane** with a fuzzy project picker (Television or fzf, your choice)
- **Enter** switches to an existing workspace for that project, or creates one if none exists
- Extra keybindings for power users: new workspace, open in editor, new tab, clear cache

## Prerequisites

- [herdr](https://herdr.dev) ≥ 0.7.0
- [pj](https://github.com/nickel-org/pj) — project directory manager
- [jq](https://jqlang.github.io/jq/) — JSON processor (used for workspace lookup)
- **One of:**
  - [Television (tv)](https://github.com/alexpasmantier/television) — rich picker with preview pane *(recommended)*
  - [fzf](https://github.com/junegunn/fzf) — widely-available fallback
- [eza](https://github.com/eza-community/eza) *(optional)* — prettier tree preview; falls back to `tree` or `ls`

## Installation

```bash
herdr plugin install josephschmitt/pj-herdr
```

Then add a keybinding of your choice to `~/.config/herdr/config.toml`:

```toml
# pj project picker
[[keys.command]]
key = "prefix+o"
type = "plugin_action"
command = "pj.open-picker"
```

Then reload:

```bash
herdr server reload-config
```

## Configuration

Create a config file at `$(herdr plugin config-dir pj)/config`:

```bash
mkdir -p "$(herdr plugin config-dir pj)"
echo "picker=tv" > "$(herdr plugin config-dir pj)/config"
```

All options are set in the config file as plain `key=value` pairs.

| Option | Default | Description |
|--------|---------|-------------|
| `picker` | `auto` | Picker backend: `tv`, `fzf`, or `auto` (prefers tv) |
| `sort` | `alpha` | Sort order: `alpha`, `priority`, or `label` |
| `sort_direction` | *(pj default)* | Sort direction: `asc` or `desc` |
| `icons` | `true` | Show marker-based icons (requires a Nerd Font) |
| `ansi` | `true` | Colorize icons with ANSI codes |
| `worktrees` | `auto` | Include git worktrees: `auto` (pj default), `yes`, or `no` |
| `no_nested` | `false` | Skip projects nested inside other projects |

## Commands

| Command | Description |
|---------|-------------|
| `pj.open-picker` | Open the project picker overlay |

Once inside the picker:

| Key | Description |
|-----|-------------|
| `Enter` | Switch to workspace (create if none exists) |
| `Ctrl-n` | Always create a new workspace |
| `Ctrl-e` | Open project in `$EDITOR` |
| `Ctrl-t` | Open new herdr tab with project as CWD |
| `Ctrl-r` | Clear pj cache and reload project list |

## Development

```bash
cd ~/development/pj-herdr

# Link for local development
herdr plugin link .

# Make scripts executable
chmod +x scripts/*.sh

# Reload herdr config
herdr server reload-config
```

## Links

- [herdr](https://herdr.dev) — terminal workspace manager
- [pj](https://github.com/nickel-org/pj) — project directory manager
- [Television](https://github.com/alexpasmantier/television) — fuzzy finder with preview
- [herdr plugin docs](https://herdr.dev/docs/plugins/)
