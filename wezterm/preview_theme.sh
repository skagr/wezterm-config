#!/usr/bin/env bash
# Called by the WezTerm fzf theme picker on focus (arrow key navigation).
# Writes the previewed theme to globals.lua so WezTerm can preview it live.
# The icon suffix is stripped before writing.
# Usage: preview_theme.sh "<theme name with icon suffix>"
GLOBALS="$HOME/.config/wezterm/globals.lua"
CURRENT=$(grep 'current_theme' "$GLOBALS" | head -1 | sed 's/.*= "\(.*\)".*/\1/')
NAME="${1% *}"
TMPFILE=$(mktemp)
cat >"$TMPFILE" <<EOF
return {
  current_theme = "$CURRENT",
  preview_theme = "$NAME",
}
EOF
mv "$TMPFILE" "$GLOBALS"
