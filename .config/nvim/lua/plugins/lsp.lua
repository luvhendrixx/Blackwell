return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      -- Debounced diagnostics: don't update while typing
      diagnostics = {
        update_in_insert = false,
        virtual_text = {
          prefix = "●",
          spacing = 4,
          source = "if_many",
        },
        severity_sort = true,
        float = {
          border = "rounded",
          source = "always",
        },
        signs = true,
        underline = true,
      },
      -- Rounded border for hover windows
      handlers = {
        ["textDocument/hover"] = vim.lsp.with(vim.lsp.handlers.hover, {
          border = "rounded",
        }),
        -- Suppress Pyright's per-keystroke progress notifications
        ["$/progress"] = function() end,
        -- Suppress Pyright's "Analyzing..." showMessage notifications
        ["window/showMessage"] = function(_, result, ctx)
          local client = vim.lsp.get_client_by_id(ctx.client_id)
          if client and client.name == "pyright" then
            return
          end
          vim.notify(result.message, vim.log.levels.INFO, { title = "LSP" })
        end,
        -- Disable Pyright's progress reporting entirely
        ["workspace/workspaceFolders"] = function() end,
        ["client/registerCapability"] = function() end,
      },
      -- Configure Pyright to be less verbose
      pyright = {
        settings = {
          python = {
            analysis = {
              typeCheckingMode = "off",
            },
          },
        },
      },
    },
  },
}
