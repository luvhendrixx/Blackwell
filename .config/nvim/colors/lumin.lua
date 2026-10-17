-- Lumin (Blur) for Neovim, ported from the Zed theme by Daksh Sharma.
-- Install: save as ~/.config/nvim/colors/lumin.lua, then :colorscheme lumin

vim.cmd("highlight clear")
if vim.fn.exists("syntax_on") == 1 then
  vim.cmd("syntax reset")
end
vim.o.termguicolors = true
vim.o.background = "dark"
vim.g.colors_name = "lumin"

-- true: Neovim paints no background, so your terminal's blur/opacity shows through.
-- false: solid #101010.
local transparent = true

local c = {
  bg = "#101010",
  surface = "#161616", -- floats, popups
  el = "#1C1C1C",
  hover = "#282828",
  thumb = "#343434",
  gutter = "#505050",
  muted = "#A0A0A0",
  faint = "#7E7E7E",
  fg = "#FFFFFF",
  text = "#D6D6DD",
  orange = "#FFC799",
  mint = "#99FFE4",
  red = "#FF8080",
  func = "#EFB080",
  kw = "#83D6C5",
  str = "#E394DC",
  num = "#EBC88D",
  type = "#87C3FF",
  builtin = "#81D2CE",
  comment = "#8A8A8A",
  attr = "#AAA0FA",
  param = "#F8C762",
  special = "#C1808A",
  bracket = "#FFD602",
  preproc = "#A8CC7C",
  tag = "#FAD075",
  link = "#88C0D0",
  const = "#666666", -- Zed uses white at ~36% alpha here; tweak to taste
  sel = "#333333",
  hit = "#5A493A", -- current search match
}

-- Black-and-white variants. Enable from lua/config/options.lua with one of:
--   vim.g.lumin_mono = true     -- grayscale UI accents, normal colored code
--   vim.g.lumin_mono = "full"   -- grayscale everything (errors stay red)
if vim.g.lumin_mono then
  c = vim.tbl_extend("force", c, {
    orange = "#FFFFFF",
    mint = "#CFCFCF",
    hit = "#4A4A4A",
  })
end
if vim.g.lumin_mono == "full" then
  c = vim.tbl_extend("force", c, {
    text = "#D0D0D0",
    func = "#E8E8E8",
    kw = "#FFFFFF",
    str = "#A8A8A8",
    num = "#C4C4C4",
    type = "#BDBDBD",
    builtin = "#BDBDBD",
    comment = "#6E6E6E",
    attr = "#8A8A8A",
    param = "#C4C4C4",
    special = "#8A8A8A",
    bracket = "#A0A0A0",
    preproc = "#A0A0A0",
    tag = "#E8E8E8",
    link = "#BDBDBD",
    const = "#9A9A9A",
    hit = "#4A4A4A",
  })
end

local none = "NONE"
local bg = transparent and none or c.bg

local groups = {
  -- Editor UI
  Normal = { fg = c.fg, bg = bg },
  NormalNC = { link = "Normal" },
  NormalFloat = { fg = c.fg, bg = c.surface },
  FloatBorder = { fg = c.hover, bg = c.surface },
  FloatTitle = { fg = c.orange, bg = c.surface },
  Cursor = { fg = c.bg, bg = c.orange },
  CursorLine = { bg = c.el },
  CursorLineNr = { fg = c.fg, bold = true },
  LineNr = { fg = c.gutter },
  SignColumn = { bg = none },
  FoldColumn = { fg = c.gutter, bg = none },
  Folded = { fg = c.muted, bg = c.el },
  ColorColumn = { bg = c.el },
  Visual = { bg = c.sel },
  VisualNOS = { bg = c.sel },
  Search = { bg = c.sel },
  IncSearch = { fg = c.fg, bg = c.hit },
  CurSearch = { fg = c.fg, bg = c.hit },
  MatchParen = { fg = c.orange, bg = c.sel, bold = true },
  NonText = { fg = c.gutter },
  Whitespace = { fg = c.gutter },
  SpecialKey = { fg = c.gutter },
  EndOfBuffer = { fg = c.bg },
  Conceal = { fg = c.faint },
  Directory = { fg = c.orange },
  Title = { fg = c.orange, bold = true },
  ErrorMsg = { fg = c.red },
  WarningMsg = { fg = c.orange },
  MoreMsg = { fg = c.mint },
  ModeMsg = { fg = c.fg },
  Question = { fg = c.mint },
  WinSeparator = { fg = c.hover },
  VertSplit = { fg = c.hover },
  StatusLine = { fg = c.muted, bg = none },
  StatusLineNC = { fg = c.faint, bg = none },
  TabLine = { fg = c.muted, bg = none },
  TabLineSel = { fg = c.fg, bg = c.el },
  TabLineFill = { bg = none },
  Pmenu = { fg = c.text, bg = c.surface },
  PmenuSel = { fg = c.fg, bg = c.hover },
  PmenuSbar = { bg = c.el },
  PmenuThumb = { bg = c.thumb },
  WildMenu = { fg = c.fg, bg = c.hover },
  Underlined = { underline = true },
  SpellBad = { undercurl = true, sp = c.red },
  SpellCap = { undercurl = true, sp = c.orange },
  SpellLocal = { undercurl = true, sp = c.mint },
  SpellRare = { undercurl = true, sp = c.muted },

  -- Classic syntax groups
  Comment = { fg = c.comment, italic = true },
  Constant = { fg = c.const },
  String = { fg = c.str },
  Character = { fg = c.str },
  Number = { fg = c.num },
  Boolean = { fg = c.const },
  Float = { fg = c.num },
  Identifier = { fg = c.text },
  Function = { fg = c.func },
  Statement = { fg = c.kw },
  Conditional = { fg = c.kw },
  Repeat = { fg = c.kw },
  Label = { fg = c.text },
  Operator = { fg = c.kw },
  Keyword = { fg = c.kw },
  Exception = { fg = c.kw },
  PreProc = { fg = c.preproc },
  Include = { fg = c.preproc },
  Define = { fg = c.preproc },
  Macro = { fg = c.preproc },
  Type = { fg = c.type },
  StorageClass = { fg = c.kw },
  Structure = { fg = c.type },
  Typedef = { fg = c.type },
  Special = { fg = c.text },
  Delimiter = { fg = c.text },
  SpecialComment = { fg = c.comment, italic = true },
  Tag = { fg = c.tag },
  Todo = { fg = c.bg, bg = c.orange, bold = true },
  Error = { fg = c.red },

  -- Treesitter
  ["@variable"] = { fg = c.text },
  ["@variable.builtin"] = { fg = c.special, italic = true },
  ["@variable.parameter"] = { fg = c.param, italic = true },
  ["@variable.member"] = { fg = c.text },
  ["@property"] = { fg = c.builtin },
  ["@constant"] = { fg = c.const },
  ["@constant.builtin"] = { fg = c.const },
  ["@boolean"] = { fg = c.const },
  ["@number"] = { fg = c.num },
  ["@string"] = { fg = c.str },
  ["@string.escape"] = { fg = c.text },
  ["@string.regexp"] = { fg = c.param },
  ["@string.special"] = { fg = c.str },
  ["@function"] = { fg = c.func },
  ["@function.call"] = { fg = c.func },
  ["@function.method"] = { fg = c.func },
  ["@function.method.call"] = { fg = c.func },
  ["@function.builtin"] = { fg = c.func },
  ["@constructor"] = { fg = c.func },
  ["@keyword"] = { fg = c.kw },
  ["@operator"] = { fg = c.kw },
  ["@type"] = { fg = c.type },
  ["@type.builtin"] = { fg = c.builtin },
  ["@attribute"] = { fg = c.attr, italic = true },
  ["@module"] = { fg = c.text },
  ["@label"] = { fg = c.text },
  ["@tag"] = { fg = c.tag },
  ["@tag.attribute"] = { fg = c.attr, italic = true },
  ["@tag.delimiter"] = { fg = c.text },
  ["@punctuation"] = { fg = c.text },
  ["@punctuation.bracket"] = { fg = c.bracket },
  ["@punctuation.delimiter"] = { fg = c.text },
  ["@comment"] = { fg = c.comment, italic = true },
  ["@comment.documentation"] = { fg = c.comment, italic = true },
  ["@markup.heading"] = { fg = c.text, bold = true },
  ["@markup.strong"] = { fg = c.param, bold = true },
  ["@markup.italic"] = { fg = c.kw, italic = true },
  ["@markup.link"] = { fg = "#81A1C1" },
  ["@markup.link.url"] = { fg = c.link, underline = true },
  ["@markup.raw"] = { fg = c.str },

  -- Diagnostics and LSP
  DiagnosticError = { fg = c.red },
  DiagnosticWarn = { fg = c.orange },
  DiagnosticInfo = { fg = c.muted },
  DiagnosticHint = { fg = c.muted },
  DiagnosticOk = { fg = c.mint },
  DiagnosticVirtualTextError = { fg = c.red, bg = "#2A1515" },
  DiagnosticVirtualTextWarn = { fg = c.orange, bg = "#2A1F15" },
  DiagnosticVirtualTextInfo = { fg = c.muted, bg = c.el },
  DiagnosticVirtualTextHint = { fg = c.muted, bg = c.el },
  DiagnosticUnderlineError = { undercurl = true, sp = c.red },
  DiagnosticUnderlineWarn = { undercurl = true, sp = c.orange },
  DiagnosticUnderlineInfo = { undercurl = true, sp = c.muted },
  DiagnosticUnderlineHint = { undercurl = true, sp = c.muted },
  LspInlayHint = { fg = c.faint, bg = c.el },
  LspReferenceText = { bg = "#262626" },
  LspReferenceRead = { bg = "#262626" },
  LspReferenceWrite = { bg = "#262626" },

  -- Diff and git
  DiffAdd = { bg = "#1B2421" },
  DiffChange = { bg = "#241F1B" },
  DiffDelete = { bg = "#241919" },
  DiffText = { bg = "#3A2F25" },
  Added = { fg = c.mint },
  Changed = { fg = c.orange },
  Removed = { fg = c.red },
  GitSignsAdd = { fg = c.mint },
  GitSignsChange = { fg = c.orange },
  GitSignsDelete = { fg = c.red },

  -- Plugins
  FlashLabel = { fg = c.bg, bg = c.orange, bold = true },
  FlashMatch = { fg = c.fg, bg = c.sel },
  SnacksIndent = { fg = c.hover },
  SnacksIndentScope = { fg = c.gutter },
  BlinkCmpLabelMatch = { fg = c.orange, bold = true },
}

for name, opts in pairs(groups) do
  vim.api.nvim_set_hl(0, name, opts)
end

-- Terminal buffer colors
local ansi = {
  c.bg, c.red, c.mint, c.orange, c.muted, c.muted, c.mint, c.fg,
  c.faint, c.red, c.mint, c.orange, c.muted, c.muted, c.mint, c.fg,
}
for i, color in ipairs(ansi) do
  vim.g["terminal_color_" .. (i - 1)] = color
end
