-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

-- Ctrl+E: jump to end of line (normal and insert)
vim.keymap.set("n", "<C-e>", "$", { desc = "End of line" })
vim.keymap.set("i", "<C-e>", "<End>", { desc = "End of line" })

-- Ctrl+W: new line below without splitting the current line
vim.keymap.set("n", "<C-w>", "o", { desc = "New line below" })
vim.keymap.set("i", "<C-w>", "<Esc>o", { desc = "New line below" })

-- Ctrl+A: select all
vim.keymap.set({ "n", "v" }, "<C-a>", "ggVG", { desc = "Select all" })
vim.keymap.set("i", "<C-a>", "<Esc>ggVG", { desc = "Select all" })
