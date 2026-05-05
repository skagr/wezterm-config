My wezterm config

![](screenshot.png)

## Requirements

- bash
- fzf

There’s some MacOS / zsh specific keybinds in wezterm.lua, but it shouldn’t be too hard to adapt.

## Features

### Opacity toggle

`<leader>O` cycles:
- All windows transparent, unfocused windows more so
- Transparency only on unfocused windows
- No transparency

### Unfocused window desaturation

`<leader>D` toggles:
- Desaturation of unfocused windows. Muted colors based on current theme

### Theme picker for WezTerm, nvim, bat

`<leader>T` opens a fuzzy theme picker

This was inspired by a [very cool example](https://github.com/CheikhNaro/wezthemes), with some tweaks:
- `Ctrl+D`, `Ctrl+L` keybinds to filter dark/light themes
- Live preview in all windows
- Choosing a wezterm theme synchronizes to `bat` and `nvim`. 
  - Updates env var exports BAT_THEME and NVIM_THEME in ~/.zshrc.local, changes applied after sourcing
  - No changes made to env vars not already exported by ~/.zshrc.local
  - Mappings present for catppuccin, tokyonight and gruvbox. Other themes fall back to catppuccin
- theme list is built dynamically (and filtered for duplicates) so it works with nightly builds
- Shell scripts (no lua dependency) with atomic writes to prevent race condition
- Tab bar follows window styling

### Keybinds

- `Ctrl+L` leader key for most commands to avoid conflicts with other apps
- `⌘+,` edit wezterm.lua (chezmoi or $EDITOR)
- New panes, tabs, windows open in a non-login shell
