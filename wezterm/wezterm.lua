local wezterm = require("wezterm")
local act = wezterm.action
local config = wezterm.config_builder()

wezterm.log_info("reloading")

-- Preferences ------------------------------------------------------------
config.font = wezterm.font_with_fallback({
	"FiraCode Nerd Font",
	"JetBrainsMono Nerd Font",
	"Symbols Nerd Font Mono",
	"monospace",
})
config.font_size = 14

-- Window
config.initial_cols = 120
config.initial_rows = 28
config.max_fps = 120
config.adjust_window_size_when_changing_font_size = false
-- config.window_close_confirmation = "NeverPrompt"
config.window_decorations = "RESIZE"
config.default_cursor_style = "SteadyBar"

-- Opacity and desaturation
local opacity = 0.90
local opacity_inactive_window = 0.75
local desaturation_inactive_window = 0.666
local opacity_tab_bar = 0
local desaturate_inactive_panes = true
config.macos_window_background_blur = 10

-- what new panes will run. Change to { "/bin/zsh", "-l" } for login shells
config.default_prog = { "/bin/zsh" }
-- where to put *_THEME env vars
local shell_rc = "~/.zshrc.local"

-- If using Homebrew, needed for shell cmds
config.set_environment_variables = {
	PATH = "/opt/homebrew/bin:" .. os.getenv("PATH"),
}

-- Theme picker -----------------------------------------------------------
local globals_path = wezterm.config_dir .. "/globals.lua"
local fallback_theme = "Catppuccin Mocha"
local builtin_schemes = wezterm.color.get_builtin_schemes()

local theme_dark = "\u{F186}"
local theme_light = "\u{F185}"
local theme_light_dark = "\u{F050E}"

local scheme_names = (function()
	local names = {}
	for name, scheme in pairs(builtin_schemes) do
		if
			not name:match("^3024")
			and not name:match("%(")
			and not name:match("^[a-z].*%-")
			and not name:match("^tokyonight")
			and scheme.background
		then
			local _, _, l, _ = wezterm.color.parse(scheme.background):hsla()
			local icon = l < 0.5 and theme_dark or theme_light
			table.insert(names, name .. " " .. icon)
		end
	end
	table.sort(names)
	return names
end)()

local ok, globals = pcall(dofile, globals_path)
if not ok then
	globals = { current_theme = fallback_theme, preview_theme = nil }
end

local function active_theme()
	return globals.preview_theme or globals.current_theme
end

local function theme_switcher(window, pane)
	local cfg_dir = wezterm.config_dir
	local themes_file = "/tmp/wezterm_themes_" .. os.getenv("USER")

	local f = io.open(themes_file, "w")
	if not f then
		wezterm.log_error("Could not write themes file: " .. themes_file)
		return
	end
	f:write(table.concat(scheme_names, "\n"))
	f:close()

	local script = string.format(
		[[
# Set pane user var so wezterm passes ctrl+j/k through to fzf
printf "\033]1337;SetUserVar=%%s=%%s\007" IS_FZF "$(echo -n true | base64)"
SELECTED=$(cat %s | fzf \
  --no-sort \
  --reverse \
  --prompt="theme %s " \
  --bind "ctrl-i:change-prompt(theme )+change-query(%s )" \
  --bind "ctrl-o:change-prompt(theme )+change-query(%s )" \
  --bind "ctrl-p:change-prompt(theme %s )+change-query()" \
  --bind "ctrl-j:down,ctrl-k:up" \
  --bind "focus:execute-silent[%s/preview_theme.sh {}]" \
  --bind "esc:execute-silent[%s/cancel_theme.sh]+abort" \
)
if [ -n "$SELECTED" ]; then
  %s/confirm_theme.sh "$SELECTED"
  export $(grep '^export' ]]
			.. shell_rc
			.. [[ | xargs)
else
  %s/cancel_theme.sh
fi
    ]],
		themes_file,
		theme_light_dark,
		theme_dark,
		theme_light,
		theme_light_dark,
		cfg_dir,
		cfg_dir,
		cfg_dir,
		cfg_dir
	)

	window:perform_action(
		act.SplitPane({
			direction = "Right",
			size = { Percent = 30 },
			command = { args = { "bash", "-c", script } },
		}),
		pane
	)
end

-- Key functions ----------------------------------------------------------
local mod = wezterm.target_triple:find("windows") and "SHIFT|CTRL" or "SHIFT|SUPER"

local function is_nvim(pane)
	return pane:get_user_vars().IS_NVIM == "true" or pane:get_foreground_process_name():find("n?vim$")
end

local function is_fzf(pane)
	return pane:get_user_vars().IS_FZF == "true" or pane:get_foreground_process_name():find("fzf$")
end

local function is_passthrough(pane, key)
	if is_nvim(pane) then
		return true
	end
	-- In fzf, only pass through ctrl+j/k (up/down navigation)
	if is_fzf(pane) then
		return key == "j" or key == "k"
	end
	return false
end

local edit_config = act.SpawnCommandInNewTab({
	cwd = wezterm.home_dir,
	args = {
		"bash",
		"-c",
		string.format(
			"sleep 0.1"
				.. " && wezterm cli set-tab-title 'config'"
				.. " && export $(grep '^export' "
				.. shell_rc
				.. " | xargs)"
				.. " && if command -v chezmoi >/dev/null 2>&1;"
				.. " then chezmoi edit --apply %q;"
				.. " else ${EDITOR:-vi} %q; fi",
			wezterm.config_file,
			wezterm.config_file
		),
	},
})

local smart_split = wezterm.action_callback(function(window, pane)
	local dim = pane:get_dimensions()
	if dim.pixel_height > dim.pixel_width then
		window:perform_action(act.SplitVertical({ domain = "CurrentPaneDomain" }), pane)
	else
		window:perform_action(act.SplitHorizontal({ domain = "CurrentPaneDomain" }), pane)
	end
end)

---@param resize_or_move "resize" | "move"
---@param mods string
---@param key string
---@param dir "Right" | "Left" | "Up" | "Down"
local function split_nav(resize_or_move, mods, key, dir)
	local event = "SplitNav_" .. resize_or_move .. "_" .. dir
	wezterm.on(event, function(win, pane)
		if is_passthrough(pane, key) then
			win:perform_action({ SendKey = { key = key, mods = mods } }, pane)
		else
			if resize_or_move == "resize" then
				win:perform_action({ AdjustPaneSize = { dir, 3 } }, pane)
			else
				local panes = pane:tab():panes_with_info()
				local is_zoomed = false
				for _, p in ipairs(panes) do
					if p.is_zoomed then
						is_zoomed = true
					end
				end
				wezterm.log_info("is_zoomed: " .. tostring(is_zoomed))
				if is_zoomed then
					dir = (dir == "Up" or dir == "Right") and "Next" or "Prev"
					wezterm.log_info("dir: " .. dir)
				end
				win:perform_action({ ActivatePaneDirection = dir }, pane)
				win:perform_action({ SetPaneZoomState = is_zoomed }, pane)
			end
		end
	end)
	return {
		key = key,
		mods = mods,
		action = wezterm.action.EmitEvent(event),
	}
end

-- Keybinds -------------------------------------------------------------------
-- config.disable_default_key_bindings = true
config.send_composed_key_when_left_alt_is_pressed = false
config.leader = { key = "L", mods = mod, timeout_milliseconds = 2000 }

config.keys = {
	{ key = "t", mods = "LEADER", action = wezterm.action_callback(theme_switcher) },
	{ key = "o", mods = "LEADER", action = act.EmitEvent("toggle-opacity") },
	{ key = "d", mods = "LEADER", action = act.EmitEvent("toggle-desaturation") },

	-- Alt+Left/Right to jump words
	{ key = "LeftArrow", mods = "OPT", action = act.SendString("\x1bb") },
	{ key = "RightArrow", mods = "OPT", action = act.SendString("\x1bf") },

	-- Edit config (Cmd+, on macOS, Ctrl+, on Linux/Windows)
	{
		key = ",",
		mods = wezterm.target_triple:find("darwin") and "SUPER" or "CTRL",
		action = edit_config,
	},
	-- Split/tab/window (non-login shells)
	{ key = "Enter", mods = mod, action = smart_split },
	{
		key = "|",
		mods = mod,
		action = act.SplitHorizontal({ domain = "CurrentPaneDomain" }),
	},
	{
		key = "-",
		mods = mod,
		action = act.SplitVertical({ domain = "CurrentPaneDomain" }),
	},
	{ key = "r", mods = "LEADER", action = act.RotatePanes("Clockwise") },

	{ key = "t", mods = "CMD", action = act.SpawnCommandInNewTab({}) },
	{ key = "n", mods = "CMD", action = act.SpawnCommandInNewWindow({}) },
	{ key = "w", mods = "CMD", action = act.CloseCurrentPane({ confirm = false }) },

	-- Pane selection
	{ key = "s", mods = "LEADER", action = wezterm.action.PaneSelect({}) },
	{ key = "z", mods = "LEADER", action = act.TogglePaneZoomState },
	-- Navigation
	split_nav("resize", "CTRL", "LeftArrow", "Left"),
	split_nav("resize", "CTRL", "RightArrow", "Right"),
	split_nav("resize", "CTRL", "UpArrow", "Up"),
	split_nav("resize", "CTRL", "DownArrow", "Down"),
	split_nav("move", "CTRL", "h", "Left"),
	split_nav("move", "CTRL", "j", "Down"),
	split_nav("move", "CTRL", "k", "Up"),
	split_nav("move", "CTRL", "l", "Right"),
}

-- Theme state ------------------------------------------------------------
wezterm.add_to_config_reload_watch_list(globals_path)

config.color_scheme = active_theme()
config.window_background_opacity = opacity

-- Tab bar ----------------------------------------------------------------
config.enable_tab_bar = true
config.use_fancy_tab_bar = false
config.tab_bar_at_bottom = true
config.hide_tab_bar_if_only_one_tab = true
config.show_new_tab_button_in_tab_bar = false

local function rgba(color, a)
	local cr, cg, cb, _ = wezterm.color.parse(color):srgba_u8()
	return "rgba(" .. cr .. ", " .. cg .. ", " .. cb .. ", " .. a .. ")"
end

local function make_tab_bar_colors(scheme_name, a)
	if not scheme_name or scheme_name == "" then
		scheme_name = fallback_theme
	end
	local s = builtin_schemes[scheme_name] or builtin_schemes[fallback_theme]
	if not s or not s.background then
		return {}
	end
	local tb = s.tab_bar
		or {
			background = s.background,
			active_tab = { bg_color = s.cursor_bg or s.foreground, fg_color = s.cursor_fg or s.background },
			inactive_tab = { bg_color = s.background, fg_color = s.foreground },
			inactive_tab_hover = { bg_color = s.background, fg_color = s.foreground },
		}
	local bg = s.background
	local active_bg = (tb.active_tab and tb.active_tab.bg_color) or s.foreground
	local active_fg = (tb.active_tab and tb.active_tab.fg_color) or s.background
	local inactive_fg = (tb.inactive_tab and tb.inactive_tab.fg_color) or s.foreground
	local hover_fg = (tb.inactive_tab_hover and tb.inactive_tab_hover.fg_color) or s.foreground
	return {
		background = rgba(bg, opacity_tab_bar),
		active_tab = {
			bg_color = rgba(active_bg, 0.6),
			fg_color = active_fg,
		},
		inactive_tab = {
			bg_color = rgba(bg, opacity_tab_bar),
			fg_color = inactive_fg,
		},
		inactive_tab_hover = {
			bg_color = rgba(bg, a),
			fg_color = hover_fg,
		},
	}
end

config.colors = {
	tab_bar = make_tab_bar_colors(active_theme(), opacity_tab_bar),
}

-- Opacity and desaturation toggles ---------------------------------------
-- 0 = both transparent, 1 = active opaque/inactive transparent, 2 = both opaque
wezterm.GLOBAL.opacity_mode = wezterm.GLOBAL.opacity_mode or 0
-- 0 = no desaturation, 1 = inactive desaturated
wezterm.GLOBAL.desat_mode = wezterm.GLOBAL.desat_mode or 1

local function apply_opacity(window)
	local overrides = window:get_config_overrides() or {}
	local mode = wezterm.GLOBAL.opacity_mode or 0
	local desat_mode = wezterm.GLOBAL.desat_mode or 1
	if window:is_focused() then
		overrides.window_background_opacity = (mode == 0) and opacity or 0.999 -- 0.999 because MacOS draws a thin white border at 1.0
		overrides.colors = { tab_bar = make_tab_bar_colors(active_theme(), overrides.window_background_opacity) }
		overrides.inactive_pane_hsb = (desaturate_inactive_panes and desat_mode == 1 and globals.preview_theme == nil)
				and {
					saturation = 1 - (desaturation_inactive_window * 0.5),
					brightness = 0.666,
				}
			or nil
	else
		overrides.window_background_opacity = (mode == 2) and 0.999 or opacity_inactive_window
		local s = builtin_schemes[active_theme()] or builtin_schemes[fallback_theme]
		local desat = (desat_mode == 1) and desaturation_inactive_window or 0
		overrides.colors = {
			tab_bar = make_tab_bar_colors(active_theme(), overrides.window_background_opacity),
			foreground = s.foreground and wezterm.color.parse(s.foreground):desaturate(desat) or nil,
			background = s.background and wezterm.color.parse(s.background):desaturate(desat) or nil,
			ansi = s.ansi and (function()
				local t = {}
				for _, c in ipairs(s.ansi) do
					table.insert(t, wezterm.color.parse(c):desaturate(desat))
				end
				return t
			end)() or nil,
			brights = s.brights and (function()
				local t = {}
				for _, c in ipairs(s.brights) do
					table.insert(t, wezterm.color.parse(c):desaturate(desat))
				end
				return t
			end)() or nil,
		}
	end
	window:set_config_overrides(overrides)
end

wezterm.on("window-focus-changed", function(window)
	apply_opacity(window)
end)

wezterm.on("toggle-opacity", function(window)
	wezterm.GLOBAL.opacity_mode = (wezterm.GLOBAL.opacity_mode + 1) % 3
	for _, mux_win in ipairs(wezterm.mux.all_windows()) do
		apply_opacity(mux_win:gui_window())
	end
end)

wezterm.on("toggle-desaturation", function(window)
	wezterm.GLOBAL.desat_mode = (wezterm.GLOBAL.desat_mode + 1) % 2
	for _, mux_win in ipairs(wezterm.mux.all_windows()) do
		apply_opacity(mux_win:gui_window())
	end
end)

wezterm.on("window-config-reloaded", function(window)
	apply_opacity(window)
end)

return config
