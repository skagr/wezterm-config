return {
  {
    "mrjones2014/smart-splits.nvim",
    opts = {
      ignored_buftypes = {
        "nofile",
        "quickfix",
        "prompt",
      },
      ignored_filetypes = { "NvimTree" },
      default_amount = 3,
      at_edge = function(ctx)
        vim.fn.system("/opt/homebrew/bin/aerospace focus " .. ctx.direction)
      end,
      float_win_behavior = "previous",
      move_cursor_same_row = false,
      cursor_follows_swapped_bufs = false,
      ignored_events = {
        "BufEnter",
        "WinEnter",
      },
      multiplexer_integration = nil,
      disable_multiplexer_nav_when_zoomed = true,
      kitty_password = nil,
      zellij_move_focus_or_tab = false,
      log_level = "info",
    },
  },
}
