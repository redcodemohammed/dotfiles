-- Hypr colorscheme. Colors come from lua/hypr_palette.lua (generated).
-- Rules: amber means focus only. Red means error only. Warnings are not amber:
-- the sign glyph tells warning from error, not the color.

local p = require("hypr_palette")
local ui, n, b = p.ui, p.normal, p.bright

vim.o.background = "dark"
vim.cmd("highlight clear")
vim.g.colors_name = "hypr"

local groups = {
  -- Editor
  Normal       = { fg = ui.fg, bg = ui.bg },
  NormalFloat  = { fg = ui.fg, bg = ui.surface },
  FloatShadow        = { bg = ui.bg }, -- no shadows
  FloatShadowThrough = { bg = ui.bg },
  FloatBorder  = { fg = ui.border, bg = ui.surface },
  FloatTitle   = { fg = ui.fg, bg = ui.surface },
  WinSeparator = { fg = ui.border },
  EndOfBuffer  = { fg = ui.bg },
  NonText      = { fg = ui.fg_dim },
  Whitespace   = { fg = ui.border },
  SpecialKey   = { fg = ui.fg_dim },
  LineNr       = { fg = ui.fg_dim },
  CursorLineNr = { fg = ui.accent },
  CursorLine   = { bg = ui.surface },
  CursorColumn = { bg = ui.surface },
  ColorColumn  = { bg = ui.surface },
  SignColumn   = { fg = ui.fg_muted },
  FoldColumn   = { fg = ui.fg_dim },
  Folded       = { fg = ui.fg_muted, bg = ui.surface },
  Visual       = { bg = ui.surface_selected },
  Search       = { fg = ui.fg, bg = ui.border },
  CurSearch    = { fg = ui.on_accent, bg = ui.accent },
  IncSearch    = { link = "CurSearch" },
  Substitute   = { link = "CurSearch" },
  MatchParen   = { fg = ui.accent, bold = true },
  StatusLine   = { fg = ui.fg, bg = ui.surface },
  StatusLineNC = { fg = ui.fg_muted, bg = ui.surface },
  TabLine      = { fg = ui.fg_muted, bg = ui.surface },
  TabLineFill  = { bg = ui.bg },
  TabLineSel   = { fg = ui.on_accent, bg = ui.accent },
  WinBar       = { fg = ui.fg, bg = ui.bg },
  WinBarNC     = { fg = ui.fg_muted, bg = ui.bg },
  Pmenu        = { fg = ui.fg, bg = ui.surface },
  PmenuSel     = { fg = ui.fg, bg = ui.surface_selected },
  PmenuSbar    = { bg = ui.surface },
  PmenuThumb   = { bg = ui.border },
  PmenuKind    = { fg = ui.fg_muted, bg = ui.surface },
  PmenuExtra   = { fg = ui.fg_muted, bg = ui.surface },
  WildMenu     = { link = "PmenuSel" },
  QuickFixLine = { bg = ui.surface_selected },
  Directory    = { fg = n.blue },
  Title        = { fg = ui.fg, bold = true },
  Question     = { fg = ui.fg },
  MoreMsg      = { fg = ui.fg },
  ModeMsg      = { fg = ui.fg },
  MsgArea      = { fg = ui.fg },
  OkMsg        = { fg = ui.fg_muted },
  ErrorMsg     = { fg = ui.alert },
  WarningMsg   = { fg = ui.fg, bold = true },
  Conceal      = { fg = ui.fg_muted },
  SpellBad     = { undercurl = true, sp = ui.alert },
  SpellCap     = { undercurl = true, sp = ui.fg_muted },
  SpellLocal   = { undercurl = true, sp = ui.fg_muted },
  SpellRare    = { undercurl = true, sp = ui.fg_muted },

  -- Syntax: muted ANSI hues, nothing amber
  Comment    = { fg = ui.fg_muted },
  Constant   = { fg = n.cyan },
  String     = { fg = n.green },
  Character  = { link = "String" },
  Number     = { link = "Constant" },
  Boolean    = { link = "Constant" },
  Float      = { link = "Constant" },
  Identifier = { fg = ui.fg },
  Function   = { fg = n.blue },
  Statement  = { fg = n.magenta },
  Keyword    = { link = "Statement" },
  Operator   = { fg = ui.fg },
  PreProc    = { fg = n.magenta },
  Type       = { fg = b.blue },
  Special    = { fg = b.cyan },
  Delimiter  = { fg = ui.fg_muted },
  Underlined = { underline = true },
  Error      = { fg = ui.alert },
  Todo       = { fg = ui.fg, bold = true },
  Added      = { fg = n.green },
  Changed    = { fg = n.blue },
  Removed    = { fg = n.red },

  -- Treesitter groups that the built-in defaults color on their own
  ["@variable"] = { fg = ui.fg },

  -- Diff
  DiffAdd    = { fg = n.green, bg = ui.surface },
  DiffChange = { fg = n.blue, bg = ui.surface },
  DiffDelete = { fg = n.red, bg = ui.surface },
  DiffText   = { fg = ui.fg, bg = ui.surface_selected },

  -- Diagnostics: red for errors only, glyph carries the rest
  DiagnosticError = { fg = ui.alert },
  DiagnosticWarn  = { fg = ui.fg },
  DiagnosticInfo  = { fg = ui.fg_muted },
  DiagnosticHint  = { fg = ui.fg_muted },
  DiagnosticOk    = { fg = ui.fg_muted },
  DiagnosticUnderlineError = { undercurl = true, sp = ui.alert },
  DiagnosticUnderlineWarn  = { undercurl = true, sp = ui.fg },
  DiagnosticUnderlineInfo  = { undercurl = true, sp = ui.fg_muted },
  DiagnosticUnderlineHint  = { undercurl = true, sp = ui.fg_muted },
  DiagnosticUnderlineOk    = { undercurl = true, sp = ui.fg_muted },
  DiagnosticDeprecated     = { strikethrough = true, sp = ui.fg_muted },
}

for name, spec in pairs(groups) do
  vim.api.nvim_set_hl(0, name, spec)
end

-- :terminal uses the same 16 colors as Alacritty.
local order = { "black", "red", "green", "yellow", "blue", "magenta", "cyan", "white" }
for i, name in ipairs(order) do
  vim.g["terminal_color_" .. (i - 1)] = n[name]
  vim.g["terminal_color_" .. (i + 7)] = b[name]
end
