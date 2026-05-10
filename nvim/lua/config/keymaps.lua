-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

vim.keymap.set("v", "<leader>p", '"_dP', { desc = "Paste over selection without clobbering register" })
vim.keymap.set("v", "<leader>ml", function()
  local url = vim.fn.getreg("+")
  vim.cmd("normal! c[" .. vim.fn.getreg('"') .. "](" .. url .. ")")
end, { desc = "Make markdown link" })

-- smart-splits
vim.keymap.set("n", "<C-Left>", require("smart-splits").resize_left)
vim.keymap.set("n", "<C-Down>", require("smart-splits").resize_down)
vim.keymap.set("n", "<C-Up>", require("smart-splits").resize_up)
vim.keymap.set("n", "<C-Right>", require("smart-splits").resize_right)
-- moving between splits
vim.keymap.set("n", "<C-h>", require("smart-splits").move_cursor_left)
vim.keymap.set("n", "<C-j>", require("smart-splits").move_cursor_down)
vim.keymap.set("n", "<C-k>", require("smart-splits").move_cursor_up)
vim.keymap.set("n", "<C-l>", require("smart-splits").move_cursor_right)
vim.keymap.set("n", "<C-\\>", require("smart-splits").move_cursor_previous)
-- swapping buffers between windows
vim.keymap.set("n", "<leader>w<C-h>", require("smart-splits").swap_buf_left, { desc = "Swap left" })
vim.keymap.set("n", "<leader>w<C-j>", require("smart-splits").swap_buf_down, { desc = "Swap down" })
vim.keymap.set("n", "<leader>w<C-k>", require("smart-splits").swap_buf_up, { desc = "Swap up" })
vim.keymap.set("n", "<leader>w<C-l>", require("smart-splits").swap_buf_right, { desc = "Swap right" })
