return {
  {
    "Saghen/blink.cmp",
    opts = {
      completion = {
        trigger = {
          prefetch_on_insert = false,
          show_on_keyword = false,
          show_on_trigger_character = true,
        },
        -- Don't auto-show the completion menu
        auto_show = false,
        -- Only show when you explicitly trigger it with Ctrl+Space
        show_on_insert = false,
      },
      providers = {
        default = {
          -- Wait 800ms after you stop typing before prompting the LSP
          delay = 800,
        },
      },
      -- Keymap: only show completion on Ctrl+Space
      keymap = {
        preset = "none",
        ["<C-Space>"] = { "show", "show_documentation", "hide_documentation" },
        ["<CR>"] = { "accept", "fallback" },
        ["<Tab>"] = { "select_next", "fallback" },
        ["<S-Tab>"] = { "select_prev", "fallback" },
        ["<Up>"] = { "select_prev", "fallback" },
        ["<Down>"] = { "select_next", "fallback" },
      },
    },
  },
}
