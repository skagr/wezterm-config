#!/usr/bin/env bash
# Called by the WezTerm fzf theme picker on ESC or abort.
# Restores the current theme by clearing preview_theme in globals.lua.
GLOBALS="$HOME/.config/wezterm/globals.lua"
CURRENT=$(grep 'current_theme' "$GLOBALS" | head -1 | sed 's/.*= "\(.*\)".*/\1/')
cat >"$GLOBALS" <<EOF
return {
  current_theme = "$CURRENT",
  preview_theme = nil,
}
EOF
