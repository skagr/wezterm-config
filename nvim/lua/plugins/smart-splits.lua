return {
  {
    "mrjones2014/smart-splits.nvim",
    opts = {
      ignored_buftypes = {
        "nofile",
        "quickfix",
        "prompt",
      },
      ignored_filetypes = { "snacks_explorer", "NvimTree", "neo-tree" },
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
    keys = {
      {
        "<C-Left>",
        function()
          require("smart-splits").resize_left()
        end,
        desc = "Resize Split Left",
      },
      {
        "<C-Down>",
        function()
          require("smart-splits").resize_down()
        end,
        desc = "Resize Split Down",
      },
      {
        "<C-Up>",
        function()
          require("smart-splits").resize_up()
        end,
        desc = "Resize Split Up",
      },
      {
        "<C-Right>",
        function()
          require("smart-splits").resize_right()
        end,
        desc = "Resize Split Right",
      },
      {
        "<C-h>",
        function()
          require("smart-splits").move_cursor_left()
        end,
        desc = "Move to Left Split",
      },
      {
        "<C-j>",
        function()
          require("smart-splits").move_cursor_down()
        end,
        desc = "Move to Below Split",
      },
      {
        "<C-k>",
        function()
          require("smart-splits").move_cursor_up()
        end,
        desc = "Move to Above Split",
      },
      {
        "<C-l>",
        function()
          require("smart-splits").move_cursor_right()
        end,
        desc = "Move to Right Split",
      },
      {
        "<C-\\>",
        function()
          require("smart-splits").move_cursor_previous()
        end,
        desc = "Move to Previous Split",
      },
      {
        "<leader><C-h>",
        function()
          require("smart-splits").swap_buf_left()
        end,
        desc = "Swap Split Left",
      },
      {
        "<leader><C-j>",
        function()
          require("smart-splits").swap_buf_down()
        end,
        desc = "Swap Split Down",
      },
      {
        "<leader><C-k>",
        function()
          require("smart-splits").swap_buf_up()
        end,
        desc = "Swap Split Up",
      },
      {
        "<leader><C-l>",
        function()
          require("smart-splits").swap_buf_right()
        end,
        desc = "Swap Split Right",
      },
    },
  },
}
