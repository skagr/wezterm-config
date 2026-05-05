#!/usr/bin/env bash
# Called by the WezTerm fzf theme picker when a theme is confirmed (Enter).
# Writes the selected theme to globals.lua (picked up by WezTerm on reload),
# and syncs the matching Neovim and bat themes to .zshrc.local.
# Falls back to catppuccin/Catppuccin Mocha if no mapping is found.
# Usage: confirm_theme.sh "<theme name with icon suffix>"

GLOBALS="$HOME/.config/wezterm/globals.lua"
ZSHRC_LOCAL="$HOME/.zshrc.local"
THEME_MAP="$HOME/.config/wezterm/theme_map.csv"
NAME="${1% *}"

MAPPED=$(grep "^${NAME}," "$THEME_MAP")
NVIM_THEME=$(echo "$MAPPED" | cut -d',' -f2)
BAT_THEME=$(echo "$MAPPED" | cut -d',' -f3)
NVIM_THEME="${NVIM_THEME:-catppuccin}"
BAT_THEME="${BAT_THEME:-Catppuccin Mocha}"

TMPFILE=$(mktemp)
cat >"$TMPFILE" <<EOF
return {
  current_theme = "$NAME",
  preview_theme = nil,
}
EOF
mv "$TMPFILE" "$GLOBALS"

sed -i '' "s/^export NVIM_THEME=.*/export NVIM_THEME=$NVIM_THEME/" "$ZSHRC_LOCAL"
sed -i '' "s/^export BAT_THEME=.*/export BAT_THEME=\"$BAT_THEME\"/" "$ZSHRC_LOCAL"
