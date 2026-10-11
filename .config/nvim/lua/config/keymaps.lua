local map = vim.keymap.set

-- Ctrl+E: end of line
map("n", "<C-e>", "$", { desc = "End of line" })
map("i", "<C-e>", "<End>", { desc = "End of line" })

-- Ctrl+W (insert only): new line below, stay in insert mode
map("i", "<C-w>", "<C-o>o", { desc = "New line below" })

-- Ctrl+A: select all
map({ "n", "v" }, "<C-a>", "ggVG", { desc = "Select all" })
map("i", "<C-a>", "<Esc>ggVG", { desc = "Select all" })

-- Terminal toggle
map({ "n", "t" }, "<M-`>", function()
  Snacks.terminal.toggle()
end, { desc = "Toggle terminal" })
map({ "n", "t" }, "<C-Space>", function()
  Snacks.terminal.toggle()
end, { desc = "Toggle terminal" })

-- Ctrl+X: toggle LSP hover
map("n", "<C-x>", function()
  if #vim.lsp.get_clients({ bufnr = 0 }) == 0 then
    vim.notify("No LSP attached to this buffer", vim.log.levels.WARN)
    return
  end
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_config(win).relative ~= "" then
      vim.api.nvim_win_close(win, false)
      return
    end
  end
  vim.lsp.buf.hover()
end, { desc = "Toggle LSP hover documentation" })
