-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

-- Helper function for terminal toggle
local function toggle_terminal()
  local term = require("toggleterm")
  term.toggle()
end

-- Ctrl+E: jump to end of line (normal and insert)
vim.keymap.set("n", "<C-e>", "$", { desc = "End of line" })
vim.keymap.set("i", "<C-e>", "<End>", { desc = "End of line" })

-- Ctrl+W: new line below without splitting the current line
vim.keymap.set("n", "<C-w>", "o", { desc = "New line below" })
vim.keymap.set("i", "<C-w>", "<Esc>o", { desc = "New line below" })

-- Ctrl+A: select all
vim.keymap.set({ "n", "v" }, "<C-a>", "ggVG", { desc = "Select all" })
vim.keymap.set("i", "<C-a>", "<Esc>ggVG", { desc = "Select all" })

-- Alt+`: toggle terminal (Ctrl+` is unreliable in most terminals)
vim.keymap.set({ "n", "t" }, "<M-`>", function() Snacks.terminal.toggle() end, { desc = "Toggle terminal" })
vim.keymap.set({ "n", "t" }, "<C-Space>", toggle_terminal, { desc = "Toggle terminal" })

-- Ctrl+X: toggle LSP hover documentation (like VS Code's hover)
vim.keymap.set("n", "<C-x>", function()
  local bufnr = vim.api.nvim_get_current_buf()
  local clients = vim.lsp.get_clients({ bufnr = bufnr })
  if #clients == 0 then
    vim.notify("No LSP attached to this buffer", vim.log.levels.WARN)
    return
  end
  -- Check if hover is already showing by trying to close it
  local windows = vim.api.nvim_list_wins()
  for _, win in windows do
    local config = vim.api.nvim_win_get_config(win)
    if config.relative ~= "" then
      -- This is a floating window, close it
      vim.api.nvim_win_close(win, false)
      return
    end
  end
  -- No floating window found, show hover
  vim.lsp.buf.hover()
end, { desc = "Toggle LSP hover documentation" })
