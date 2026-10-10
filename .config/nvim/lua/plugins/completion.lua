return {
  {
    "saghen/blink.cmp",
    opts = {
      completion = {
        -- Only show on trigger characters (like `.` or `::`) or manual Ctrl+Space
        -- This prevents the popup from appearing on every keystroke
        trigger = {
          show_on_keyword = false,
          show_on_trigger_character = true,
          show_on_insert = false,
        },
        menu = {
          auto_show = false,
        },
      },
    },
  },
}
