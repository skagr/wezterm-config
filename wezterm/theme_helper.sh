#!/bin/bash
show_help() {
  cat <<EOF
Called by WezTerm fzf theme picker

USAGE: ${0##*/} [-h|--help] SUBCOMMAND [ARGS]

SUBCOMMANDS:
    preview THEME   Preview THEME
    confirm THEME   Apply THEME to Wezterm, Neovim & Bat
    cancel          Restore current them by clearing preview_theme
EOF
}

get_current_theme() {
  local line name theme
  while read -r line; do
    case "${line}" in
    *"current_theme = "*)
      theme="${line##*= \"}"   # strip up to opening quote
      theme="${theme%%\"*}"    # strip from closing quote onward
      printf '%s\n' "${theme}"
      break
      ;;
    esac
  done <"${globals}"
}

# Atomically rewrites globals.lua. preview_theme is nil
# when omitted — WezTerm uses nil to detect that no preview is active.
update_globals() {
  (($# == 2)) &&
    set -- "${1}" "\"${2}\""
  cat <<EOF >"${globals}.tmp"
return {
    current_theme = "${1}",
    preview_theme = ${2:-nil},
}
EOF
  mv -f "${globals}.tmp" "${globals}"
}

# Atomically rewrites shell_rc, substituting only NVIM_THEME and BAT_THEME
# export lines in-place so all other contents are preserved unchanged.
# Also updates globals.lua so WezTerm reflects the confirmed theme immediately.
# $1: wezterm_theme  $2: nvim_theme  $3: bat_theme  $4: /path/to/shell_rc
set_theme() {
  local tmp line
  tmp="${4}.tmp"

  while read -r line; do
    case "${line}" in
    "export NVIM_THEME="*)
      printf 'export NVIM_THEME="%s"\n' "${2}" >>"${tmp}"
      ;;
    "export BAT_THEME="*)
      printf 'export BAT_THEME="%s"\n' "${3}" >>"${tmp}"
      ;;
    *)
      printf '%s\n' "${line}" >>"${tmp}"
      ;;
    esac
  done <"${4}"

  update_globals "${1}"
  mv "${tmp}" "${4}"
}

# Looks up a WezTerm theme name in theme_map.csv (format: wezterm,nvim,bat)
# and returns the remainder of the matching line: "nvim_theme,bat_theme".
get_app_themes() {
  local line
  while read -r line; do
    case "${line}" in
    "${1},"*)
      printf '%s\n' "${line#*,}"
      break
      ;;
    esac
  done <"${theme_map}"
}

# ${1% *} strips the trailing icon fzf appends to theme names for display.
preview_theme() {
  local current
  current="$(get_current_theme)"
  update_globals "${current}" "${1% *}"
}

cancel_theme() {
  local current
  current="$(get_current_theme)"
  update_globals "${current}"
}

# Falls back to catppuccin/Catppuccin Mocha when the theme isn't in theme_map.csv.
# ${1% *} strips the trailing icon fzf appends to theme names for display.
confirm_theme() {
  local shell_rc name
  shell_rc="${HOME}/.zshrc.local"
  name="${1% *}"

  local mapped nvim bat
  mapped="$(get_app_themes "${name}")"
  nvim="${mapped%,*}"
  bat="${mapped##*,}"

  nvim="${nvim:-catppuccin}"
  bat="${bat:-Catppuccin Mocha}"

  set_theme "${name}" "${nvim}" "${bat}" "${shell_rc}"
}

main() {
  local globals theme_map
  globals="${HOME}/.config/wezterm/globals.lua"
  theme_map="${HOME}/.config/wezterm/theme_map.csv"

  case "$(printf '%s' "${1}" | tr '[:upper:]' '[:lower:]')" in
  "-h" | "--help")
    show_help
    return 0
    ;;
  "preview")
    preview_theme "${2}"
    ;;
  "cancel")
    cancel_theme
    ;;
  "confirm")
    confirm_theme "${2}"
    ;;
  *)
    printf 'Unrecognized subcommand: %s\n' "${1}" >&2
    return 1
    ;;
  esac

  return 0
}

main "${@}"
