-- onedark.lua — minimal onedark-inspired Neovim colorscheme

local hl = vim.api.nvim_set_hl
local none = "NONE"

-- One Dark palette
local p = {
  bg        = "#1e222a",
  bg_alt    = "#21252b",
  fg        = "#abb2bf",
  fg_dark   = "#828997",
  red       = "#e06c75",
  orange    = "#d19a66",
  yellow    = "#e5c07b",
  green     = "#98c379",
  cyan      = "#56b6c2",
  blue      = "#61afef",
  purple    = "#c678dd",
  comment   = "#5c6370",
  gutter    = "#4b5263",
  cursorln  = "#2c323c",
}

-- Reset highlights to avoid clashes
vim.cmd("highlight clear")
if vim.fn.exists("syntax_on") == 1 then vim.cmd("syntax reset") end
vim.g.colors_name = "onedark"

-- Editor
hl(0, "Normal",        { fg = p.fg, bg = p.bg })
hl(0, "NormalNC",      { fg = p.fg_dark, bg = p.bg })
hl(0, "CursorLine",    { bg = p.cursorln })
hl(0, "CursorColumn",  { bg = p.cursorln })
hl(0, "ColorColumn",   { bg = p.cursorln })
hl(0, "CursorLineNr",  { fg = p.yellow, bold = true })
hl(0, "LineNr",        { fg = p.gutter })
hl(0, "SignColumn",    { bg = p.bg })
hl(0, "VertSplit",     { fg = p.bg_alt })
hl(0, "StatusLine",    { fg = p.fg, bg = p.bg_alt })
hl(0, "StatusLineNC",  { fg = p.comment, bg = p.bg_alt })
hl(0, "WinSeparator",  { fg = p.bg_alt })

-- UI elements
hl(0, "Pmenu",         { fg = p.fg, bg = p.bg_alt })
hl(0, "PmenuSel",      { fg = p.bg, bg = p.blue })
hl(0, "PmenuSbar",     { bg = p.bg_alt })
hl(0, "PmenuThumb",    { bg = p.comment })
hl(0, "Visual",        { bg = p.bg_alt })
hl(0, "Search",        { fg = p.bg, bg = p.orange })
hl(0, "IncSearch",     { fg = p.bg, bg = p.yellow })
hl(0, "MatchParen",    { fg = p.yellow, bg = p.bg_alt, bold = true })
hl(0, "Folded",        { fg = p.comment, bg = p.bg_alt, italic = true })
hl(0, "FoldColumn",    { fg = p.comment, bg = p.bg })

-- Text / syntax
hl(0, "Comment",       { fg = p.comment, italic = true })
hl(0, "Constant",      { fg = p.cyan })
hl(0, "String",        { fg = p.green })
hl(0, "Character",     { fg = p.green })
hl(0, "Number",        { fg = p.orange })
hl(0, "Boolean",       { fg = p.orange })
hl(0, "Identifier",    { fg = p.red })
hl(0, "Function",      { fg = p.blue })
hl(0, "Statement",     { fg = p.purple })
hl(0, "Keyword",       { fg = p.purple })
hl(0, "Conditional",   { fg = p.purple })
hl(0, "Repeat",        { fg = p.purple })
hl(0, "Operator",      { fg = p.fg })
hl(0, "Type",          { fg = p.yellow })
hl(0, "StorageClass",  { fg = p.yellow })
hl(0, "Structure",     { fg = p.yellow })
hl(0, "Special",       { fg = p.orange })
hl(0, "Underlined",    { fg = p.cyan, underline = true })
hl(0, "Todo",          { fg = p.purple, bold = true })
hl(0, "Error",         { fg = p.red, bold = true })

-- Diagnostics
hl(0, "DiagnosticError", { fg = p.red })
hl(0, "DiagnosticWarn",  { fg = p.yellow })
hl(0, "DiagnosticInfo",  { fg = p.blue })
hl(0, "DiagnosticHint",  { fg = p.cyan })
hl(0, "DiagnosticUnderlineError", { undercurl = true, sp = p.red })
hl(0, "DiagnosticUnderlineWarn",  { undercurl = true, sp = p.yellow })
hl(0, "DiagnosticUnderlineInfo",  { undercurl = true, sp = p.blue })
hl(0, "DiagnosticUnderlineHint",  { undercurl = true, sp = p.cyan })

-- Diff / git
hl(0, "DiffAdd",    { fg = p.green, bg = none })
hl(0, "DiffDelete", { fg = p.red, bg = none })
hl(0, "DiffChange", { fg = p.yellow, bg = none })
hl(0, "DiffText",   { fg = p.blue, bg = none })

-- LSP / Treesitter link groups (basic)
hl(0, "@function",  { link = "Function" })
hl(0, "@keyword",   { link = "Keyword" })
hl(0, "@string",    { link = "String" })
hl(0, "@comment",   { link = "Comment" })
hl(0, "@type",      { link = "Type" })
hl(0, "@variable",  { fg = p.fg })

-- End of scheme
