#!/bin/bash
show_help() {
  cat <<EOF
Called by WezTerm fzf theme picker

USAGE: ${0##*/} [-h|--help] SUBCOMMAND [ARGS]

SUBCOMMANDS:
    pick THEMES_FILE SHELL_RC   Run fzf theme picker
    preview THEME               Preview THEME
    confirm THEME SHELL_RC      Apply THEME to Wezterm, Neovim & Bat; write env vars to SHELL_RC
    cancel                      Restore current theme by clearing preview_theme
EOF
}

get_current_theme() {
  local line name theme
  while read -r line; do
    case "${line}" in
    *"current_theme = "*)
      theme="${line##*= \"}" # strip up to opening quote
      theme="${theme%%\"*}"  # strip from closing quote onward
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

# Atomically rewrites shell_rc, substituting WEZTERM_THEME, NVIM_THEME and BAT_THEME
# export lines in-place; other lines are preserved unchanged. Each substitution
# is a no-op if the line doesn't exist in shell_rc.
# Also updates globals.lua so WezTerm reflects the confirmed theme immediately.
# $1: wezterm_theme  $2: nvim_theme  $3: bat_theme  $4: /path/to/shell_rc
set_theme() {
  local tmp line
  tmp="${4}.tmp"

  while read -r line; do
    case "${line}" in
    "export WEZTERM_THEME="*)
      printf 'export WEZTERM_THEME="%s"\n' "${1}" >>"${tmp}"
      ;;
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

# fzf theme picker with live preview
# Ctrl-T cycles Dark/Light/All prefilter
# Ctrl-J/K to scroll
pick_theme() {
  local themes_file="${1}" shell_rc="${2}" cfg_dir selected
  local dark light light_dark
  cfg_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  dark=$(printf '\xef\x86\x86')           # U+F186
  light=$(printf '\xef\x86\x85')          # U+F185
  light_dark=$(printf '\xf3\xb0\x94\x8e') # U+F050E

  local act_all act_dark act_light preview cancel cycle
  act_all="reload(cat ${themes_file})+change-prompt(theme ${light_dark} )"
  act_dark="reload(grep -F ${dark} ${themes_file})+change-prompt(theme ${dark} )"
  act_light="reload(grep -F ${light} ${themes_file})+change-prompt(theme ${light} )"
  preview="execute-silent[${cfg_dir}/theme_helper.sh preview {}]"
  cancel="execute-silent[${cfg_dir}/theme_helper.sh cancel]"
  cycle="if [[ \$FZF_PROMPT == 'theme ${light_dark} ' ]]; then echo '${act_dark}';"
  cycle+=" elif [[ \$FZF_PROMPT == 'theme ${dark} ' ]]; then echo '${act_light}';"
  cycle+=" else echo '${act_all}'; fi"

  printf "\033]1337;SetUserVar=%s=%s\007" IS_FZF "$(printf 'true' | base64)" # Ctrl-J/K passthrough

  selected=$(fzf \
    --header="Ctrl-T to filter Dark/Light" \
    --reverse \
    --prompt="theme ${light_dark} " \
    --bind "ctrl-t:transform:${cycle}" \
    --bind "ctrl-j:down,ctrl-k:up" \
    --bind "load:${preview}" \
    --bind "focus:${preview}" \
    --bind "esc:${cancel}+abort" \
    <"${themes_file}")

  printf "\033]1337;SetUserVar=%s=%s\007" IS_FZF "$(printf 'false' | base64)"

  if [ -n "${selected}" ]; then
    "${cfg_dir}/theme_helper.sh" confirm "${selected}" "${shell_rc}"
    export $(grep '^export' "${shell_rc}" | xargs)
  else
    "${cfg_dir}/theme_helper.sh" cancel
  fi
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
  shell_rc="${2}"
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
  "pick")
    pick_theme "${2}" "${3}"
    ;;
  "preview")
    preview_theme "${2}"
    ;;
  "cancel")
    cancel_theme
    ;;
  "confirm")
    confirm_theme "${2}" "${3}"
    ;;
  *)
    printf 'Unrecognized subcommand: %s\n' "${1}" >&2
    return 1
    ;;
  esac

  return 0
}

main "${@}"
