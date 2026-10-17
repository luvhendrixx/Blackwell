return {
  { "mason-org/mason.nvim", opts = { ensure_installed = { "ols" } } },
  { "nvim-treesitter/nvim-treesitter", opts = { ensure_installed = { "odin" } } },
  { "neovim/nvim-lspconfig", opts = { servers = { ols = {} } } },
}
