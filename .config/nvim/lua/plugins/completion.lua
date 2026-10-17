return {
  {
    "saghen/blink.cmp",
    opts = {
      completion = {
        -- Only show on trigger characters (like `.` or `::`) or manual Ctrl+Space
        trigger = {
          prefetch_on_insert = false,
          show_on_keyword = false,
          show_on_trigger_character = true,
          show_on_insert = false,
        },
        menu = {
          auto_show = false,
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
