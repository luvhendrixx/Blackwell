-- Suppress Pyright notifications globally
local orig_notify = vim.notify
vim.notify = function(msg, level, opts)
  if type(msg) == "string" and msg:lower():match("pyright") then
    return
  end
  orig_notify(msg, level, opts)
end

-- Suppress Pyright notifications globally
local orig_notify = vim.notify
vim.notify = function(msg, level, opts)
  if type(msg) == "string" and msg:lower():match("pyright") then
    return
  end
  orig_notify(msg, level, opts)
end

-- bootstrap lazy.nvim, LazyVim and your plugins
require("config.lazy")
