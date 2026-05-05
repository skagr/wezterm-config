-- Keybinds ---------------------------------------------------------------
-- CTRL+L            leader key
--
-- LEADER+|          split pane right
-- LEADER+-          split pane down
-- LEADER+H/J/K/L    navigate panes
-- LEADER+←/→        rotate panes
--
-- CMD+T             new tab
-- CMD+N             new window
-- CMD+W             close pane, tab, window
--
-- LEADER+O          cycle opacity settings:
--   all windows transparent, only inactive windows, no transparency
-- LEADER+D          toggle desaturation of inactive windows
--
-- CMD+,             edit config (chezmoi)
-- OPT+←/→           jump word
--
-- LEADER+T          theme switcher (fzf)
--   CTRL-D            filter dark themes
--   CTRL-L            filter light themes (CTRL-L, CTRL-L if using CTRL-L as leader)
--   CTRL-A            show all themes
--   ENTER             confirm theme
--   ESC               cancel (restore previous theme)
---------------------------------------------------------------------------

local wezterm = require("wezterm")
local act = wezterm.action
local config = wezterm.config_builder()

config.set_environment_variables = {
	PATH = "/opt/homebrew/bin:" .. os.getenv("PATH"),
}

-- Preferences ------------------------------------------------------------
-- Font
config.font = wezterm.font_with_fallback({
	"FiraCode Nerd Font",
	"Symbols Nerd Font Mono",
	"monospace",
})
config.font_size = 14

-- Opacity and desaturation
local opacity = 0.90
local opacity_inactive_window = 0.75
local desaturation_inactive_window = 0.7
local opacity_tab_bar = 0
local desaturate_inactive_panes = true
local background_blur = 10

-- Theme state ------------------------------------------------------------
local globals_path = wezterm.config_dir .. "/globals.lua"
wezterm.add_to_config_reload_watch_list(globals_path)
local fallback_theme = "Catppuccin Mocha"
local builtin_schemes = wezterm.color.get_builtin_schemes()

-- Nerd Font icons appended as suffix ( dark,  light) so fzf theme picker
-- can filter by icon
local moon = "\u{F186}"
local sun = "\u{F185}"

local scheme_names = (function()
	local names = {}
	for name, scheme in pairs(builtin_schemes) do
		if
			not name:match("^3024") -- My eyes!
			and not name:match("%(") -- duplicates
			and not name:match("^[a-z].*%-") -- duplicates
			and not name:match("^tokyonight") -- duplicates
			and scheme.background
		then
			-- Use HSLA lightness on the background color to detect dark/light
			local _, _, l, _ = wezterm.color.parse(scheme.background):hsla()
			local icon = l < 0.5 and moon or sun
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

config.color_scheme = active_theme()
config.window_background_opacity = opacity
config.macos_window_background_blur = background_blur

if
	desaturate_inactive_panes and globals.preview_theme == nil -- theme picker not active
then
	config.inactive_pane_hsb = {
		saturation = 1 - (desaturation_inactive_window * 0.666),
		brightness = 0.666,
	}
end

-- Window -----------------------------------------------------------------
config.initial_cols = 120
config.initial_rows = 28
config.max_fps = 120
config.adjust_window_size_when_changing_font_size = false
config.window_close_confirmation = "NeverPrompt"
config.window_decorations = "RESIZE"
config.default_cursor_style = "SteadyBar"

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
	if window:is_focused() then
		overrides.window_background_opacity = (mode == 0) and opacity or 0.999 -- .999 because osx draws a thin border otherwise
		overrides.colors = { tab_bar = make_tab_bar_colors(active_theme(), overrides.window_background_opacity) }
	else
		overrides.window_background_opacity = (mode == 2) and 0.999 or opacity_inactive_window
		local s = builtin_schemes[active_theme()] or builtin_schemes[fallback_theme]

		local desat_mode = wezterm.GLOBAL.desat_mode or 1
		local desat = (desat_mode == 1) and desaturation_inactive_window or 0

		overrides.colors = {
			tab_bar = make_tab_bar_colors(active_theme(), overrides.window_background_opacity),
			foreground = wezterm.color.parse(s.foreground):desaturate(desat),
			background = wezterm.color.parse(s.background):desaturate(desat),
			ansi = (function()
				local t = {}
				for _, c in ipairs(s.ansi) do
					table.insert(t, wezterm.color.parse(c):desaturate(desat))
				end
				return t
			end)(),
			brights = (function()
				local t = {}
				for _, c in ipairs(s.brights) do
					table.insert(t, wezterm.color.parse(c):desaturate(desat))
				end
				return t
			end)(),
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

-- Theme switcher ---------------------------------------------------------
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
SELECTED=$(cat %s | fzf \
  --no-sort \
  --reverse \
  --prompt="🎨 theme > " \
  --bind "ctrl-d:change-query(%s )" \
  --bind "ctrl-l:change-query(%s )" \
  --bind "ctrl-a:change-query()" \
  --bind "focus:execute-silent[%s/preview_theme.sh {}]" \
  --bind "esc:execute-silent[%s/cancel_theme.sh]+abort" \
)
if [ -n "$SELECTED" ]; then
  %s/confirm_theme.sh "$SELECTED"
  source ~/.zshrc.local
else
  %s/cancel_theme.sh
fi
    ]],
		themes_file, -- cat %s
		moon, -- ctrl-d: change-query(%s ) → filter dark
		sun, -- ctrl-l: change-query(%s ) → filter light
		cfg_dir, -- focus: preview_theme.sh
		cfg_dir, -- esc: cancel_theme.sh
		cfg_dir, -- enter: confirm_theme.sh
		cfg_dir -- else: cancel_theme.sh
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

-- Keys -------------------------------------------------------------------
config.send_composed_key_when_left_alt_is_pressed = false
config.leader = { key = "l", mods = "CTRL", timeout_milliseconds = 1000 }

config.keys = {
	-- Pass CTRL+L through when already in leader mode
	{
		key = "l",
		mods = "LEADER|CTRL",
		action = wezterm.action.SendKey({ key = "l", mods = "CTRL" }),
	},
	-- Theme switcher
	{
		key = "t",
		mods = "LEADER",
		action = wezterm.action_callback(theme_switcher),
	},
	-- Toggle opacity
	{
		key = "o",
		mods = "LEADER",
		action = wezterm.action.EmitEvent("toggle-opacity"),
	},
	-- Toggle desaturation
	{
		key = "d",
		mods = "LEADER",
		action = wezterm.action.EmitEvent("toggle-desaturation"),
	},
	-- Edit config
	{
		key = ",",
		mods = "SUPER",
		action = wezterm.action.SpawnCommandInNewTab({
			cwd = wezterm.home_dir,
			args = {
				"bash",
				"-c",
				string.format(
					"sleep 0.1 && wezterm cli set-tab-title 'config' && source ~/.zshrc.local && chezmoi edit --apply %q",
					-- "sleep 0.1 && wezterm cli set-tab-title 'config' && source ~/.zshrc.local && nvim %q",
					wezterm.config_file
				),
			},
		}),
	},
	-- Alt+Left/Right to jump words
	{
		key = "LeftArrow",
		mods = "OPT",
		action = wezterm.action.SendString("\x1bb"),
	},
	{
		key = "RightArrow",
		mods = "OPT",
		action = wezterm.action.SendString("\x1bf"),
	},
	-- Splits (non-login shells)
	{
		key = "|",
		mods = "LEADER",
		action = wezterm.action.SplitHorizontal({
			domain = "CurrentPaneDomain",
			args = { "/bin/zsh" },
		}),
	},
	{
		key = "-",
		mods = "LEADER",
		action = wezterm.action.SplitVertical({
			domain = "CurrentPaneDomain",
			args = { "/bin/zsh" },
		}),
	},
	-- New tab/window (non-login shells)
	{
		key = "t",
		mods = "CMD",
		action = act.SpawnCommandInNewTab({
			args = { "/bin/zsh" },
		}),
	},
	{
		key = "n",
		mods = "CMD",
		action = act.SpawnCommandInNewWindow({
			args = { "/bin/zsh" },
		}),
	},
	-- Close pane
	{
		key = "w",
		mods = "CMD",
		action = wezterm.action.CloseCurrentPane({ confirm = false }),
	},
	-- Navigate panes
	{
		key = "h",
		mods = "LEADER",
		action = wezterm.action.ActivatePaneDirection("Left"),
	},
	{
		key = "l",
		mods = "LEADER",
		action = wezterm.action.ActivatePaneDirection("Right"),
	},
	{
		key = "k",
		mods = "LEADER",
		action = wezterm.action.ActivatePaneDirection("Up"),
	},
	{
		key = "j",
		mods = "LEADER",
		action = wezterm.action.ActivatePaneDirection("Down"),
	},
	-- Rotate panes
	{
		key = "LeftArrow",
		mods = "LEADER",
		action = wezterm.action.RotatePanes("CounterClockwise"),
	},
	{
		key = "RightArrow",
		mods = "LEADER",
		action = wezterm.action.RotatePanes("Clockwise"),
	},
}

return config
