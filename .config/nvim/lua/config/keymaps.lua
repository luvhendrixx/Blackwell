local map = vim.keymap.set

-- Ctrl+e: jump to end of line (insert mode)
map("i", "<C-e>", "<End>", { desc = "End of line" })

-- Ctrl+w: open a new line below, stay in insert mode, current line untouched
map("i", "<C-w>", "<C-o>o", { desc = "New line below" })

-- Ctrl+`: toggle terminal
map({ "n", "i", "t" }, "<C-`>", function()
  Snacks.terminal()
end, { desc = "Toggle terminal" })

-- Ctrl+a: select everything (like an IDE)
map({ "n", "i" }, "<C-a>", "<Esc>ggVG", { desc = "Select all" })
