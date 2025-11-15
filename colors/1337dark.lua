-- 1337dark.lua — minimal onedark-inspired Neovim colorscheme (tweaked to my liking)

local hl = vim.api.nvim_set_hl

-- One Dark palette
local p = {
    bg_light     = "#323232",
    bg           = "#202020",
    bg_dark      = "#151515",
    bg_darker    = "#101010",
    fg_light     = "#dadada",
    fg           = "#ababab",
    fg_alt       = "#828282",
    comment      = "#506070",
    gutter       = "#405060",
    cursorln     = "#1c2c3c",

    white        = "#ffffff",
    black        = "#000000",
    none         = "none",

    red_light    = "#f08c95",
    red          = "#f04c65",
    red_dark     = "#ff4c55",

    orange_light = "#f1ba86",
    orange       = "#d19a66",
    orange_dark  = "#d17a46",

    yellow_light = "#f5f07b",
    yellow       = "#f5d07b",
    yellow_dark  = "#c5c00b",

    green_light  = "#d8ffb9",
    green        = "#98c379",
    green_dark   = "#78a359",

    cyan_light   = "#76d6e2",
    cyan         = "#56b6c2",
    cyan_dark    = "#36b6a2",

    blue_light   = "#81cfff",
    blue         = "#61afef",
    blue_dark    = "#418dde",

    purple_light = "#e698fd",
    purple       = "#c678dd",
    purple_dark  = "#ae60c4",
}

-- Reset highlights to avoid clashes
vim.cmd("highlight clear")
if vim.fn.exists("syntax_on") == 1 then vim.cmd("syntax reset") end
vim.g.colors_name = "1337dark"

-- TODO: Go through all of these to see what they do
hl(0, "Normal", { fg = p.fg, bg = p.bg })
hl(0, "NormalNC", { fg = p.fg_alt, bg = p.bg_darker })
hl(0, "EndOfBuffer", { fg = p.fg, bg = p.bg_dark })

-- Floating windows
hl(0, "NormalFloat", { fg = p.fg_light, bg = p.bg_dark })
hl(0, "FloatBorder", { fg = p.blue, bg = p.bg_dark })
hl(0, "FloatTitle", { fg = p.yellow, bg = p.bg_dark, bold = true })
hl(0, "FloatFooter", { fg = p.orange_light, bg = p.bg, italic = true })

hl(0, "SignColumn", { bg = p.cursorln })
hl(0, "GitSignsAdd", { fg = p.green_dark, bg = p.gutter })
hl(0, "GitSignsChange", { fg = p.blue_dark, bg = p.gutter })
hl(0, "GitSignsDelete", { fg = p.red_dark, bg = p.gutter })
hl(0, "FoldColumn", { fg = p.yellow, bg = p.cursorln, bold = true })
hl(0, "Folded", { fg = p.yellow_dark, bg = p.bg_light, italic = true })

-- Cursor styles
hl(0, "Cursor", { reverse = true })
hl(0, "lCursor", { link = "Cursor" })
hl(0, "CursorIM", { link = "Cursor" })
hl(0, "TermCursor", { link = "Cursor" })
hl(0, "CursorLine", { bg = p.cursorln })
hl(0, "CursorColumn", { bg = p.cursorln })
hl(0, "ColorColumn", { bg = p.cursorln })
hl(0, "CursorLineNr", { fg = p.yellow_light, bold = true })
hl(0, "LineNr", { fg = p.red })
hl(0, "CursorLineFold", { bg = p.yellow })
hl(0, "CursorLineSign", { bg = p.yellow })

-- Messages / cmdline area
hl(0, "ModeMsg", { fg = p.cyan })
hl(0, "MsgArea", { fg = p.fg, bg = p.bg })
hl(0, "MsgSeparator", { fg = p.white, bg = p.bg })
hl(0, "MoreMsg", { fg = p.orange_dark, bg = p.fg_light })

hl(0, "ErrorMsg", { fg = p.red, bold = true })
hl(0, "WarningMsg", { fg = p.orange, bold = true })

hl(0, "DiffAdd", { fg = p.green, bg = p.none })
hl(0, "DiffText", { fg = p.blue, bg = p.none })
hl(0, "DiffChange", { fg = p.yellow, bg = p.none })
hl(0, "DiffDelete", { fg = p.red, bg = p.none })

hl(0, "VertSplit", { fg = p.bg_dark, bg = p.red })
hl(0, "StatusLine", { fg = p.yellow, bg = p.bg_dark })
hl(0, "StatusLineNC", { fg = p.comment, bg = p.bg_dark })
hl(0, "WinSeparator", { fg = p.white })

-- Buffers
hl(0, 'BufferCurrent', { fg = '#1c2526', bg = '#d0d0d0', bold = true })
hl(0, 'BufferCurrentSign', { fg = '#1c2526', bg = '#d0d0d0' })
hl(0, 'BufferCurrentMod', { fg = '#a8334c', bg = '#d0d0d0', bold = true })
hl(0, 'BufferVisible', { fg = '#4a5859', bg = '#e0e0e0' })
hl(0, 'BufferVisibleSign', { fg = '#4a5859', bg = '#e0e0e0' })
hl(0, 'BufferInactive', { fg = '#6b7280', bg = '#f0f0f0' })
hl(0, 'BufferInactiveSign', { fg = '#6b7280', bg = '#f0f0f0' })
hl(0, 'BufferTabpageFill', { fg = '#6b7280', bg = '#f5f5f5' })

-- UI elements long
hl(0, "Pmenu", { fg = p.fg, bg = p.bg_dark })
hl(0, "PmenuSel", { fg = p.bg, bg = p.blue })
hl(0, "PmenuSbar", { bg = p.bg_dark })
hl(0, "PmenuThumb", { bg = p.comment })
hl(0, "Visual", { reverse = true })
hl(0, "Search", { fg = p.bg, bg = p.orange })
hl(0, "IncSearch", { fg = p.bg, bg = p.yellow })
hl(0, "MatchParen", { fg = p.yellow, bg = p.bg_dark, bold = true })

-- Text / syntax
hl(0, "Comment", { fg = p.comment, italic = true })
hl(0, "Constant", { fg = p.cyan })
hl(0, "String", { fg = p.green })
hl(0, "Character", { fg = p.green })
hl(0, "Number", { fg = p.orange })
hl(0, "Boolean", { fg = p.orange })
hl(0, "Identifier", { fg = p.red })
hl(0, "Function", { fg = p.blue })
hl(0, "Statement", { fg = p.purple })
hl(0, "Keyword", { fg = p.purple })
hl(0, "Conditional", { fg = p.purple })
hl(0, "Repeat", { fg = p.purple })
hl(0, "Operator", { fg = p.fg })
hl(0, "Type", { fg = p.yellow })
hl(0, "StorageClass", { fg = p.yellow })
hl(0, "Structure", { fg = p.yellow })
hl(0, "Special", { fg = p.orange })
hl(0, "Underlined", { fg = p.cyan, underline = true })
hl(0, "Todo", { fg = p.purple, bold = true })
hl(0, "Error", { fg = p.red, bold = true })

-- Diagnostics
hl(0, "DiagnosticError", { fg = p.red })
hl(0, "DiagnosticWarn", { fg = p.yellow })
hl(0, "DiagnosticInfo", { fg = p.blue })
hl(0, "DiagnosticHint", { fg = p.cyan })
hl(0, "DiagnosticUnderlineError", { undercurl = true, sp = p.red })
hl(0, "DiagnosticUnderlineWarn", { undercurl = true, sp = p.yellow })
hl(0, "DiagnosticUnderlineInfo", { undercurl = true, sp = p.blue })
hl(0, "DiagnosticUnderlineHint", { undercurl = true, sp = p.cyan })

-- Diff / git

-- LSP / Treesitter link groups (basic)
hl(0, "@function", { link = "Function" })
hl(0, "@keyword", { link = "Keyword" })
hl(0, "@string", { link = "String" })
hl(0, "@comment", { link = "Comment" })
hl(0, "@type", { link = "Type" })
hl(0, "@variable", { fg = p.fg })

-- Personal highlights for my comment tags
hl(0, "1337TagTODO", { fg = p.purple_dark, bg = p.white, bold = true })
hl(0, "1337TagTEST", { fg = p.cyan_dark, bg = p.white, bold = true })
hl(0, "1337TagPASS", { fg = p.green_dark, bg = p.white, bold = true })
hl(0, "1337TagPERF", { fg = p.green_dark, bg = p.white, bold = true })
hl(0, "1337TagFAIL", { fg = p.red_dark, bg = p.white, bold = true })
hl(0, "1337TagWARN", { fg = p.orange_dark, bg = p.white, bold = true })
hl(0, "1337TagNOTE", { fg = p.blue_dark, bg = p.white, bold = true })

-- TODO: Go through these later Made by chatgpt
-- Whitespace / NonText
hl(0, "NonText", { fg = p.gutter })
hl(0, "Whitespace", { fg = p.gutter })
hl(0, "SpecialKey", { fg = p.gutter })

-- Tabline
hl(0, "TabLine", { fg = p.orange_dark, bg = p.black })
hl(0, "TabLineSel", { fg = p.fg, bg = p.red, bold = true })
hl(0, "TabLineFill", { fg = p.yellow_dark, bg = p.black })

-- Winbar
hl(0, "WinBar", { fg = p.fg, bg = p.bg_dark })
hl(0, "WinBarNC", { fg = p.fg_alt, bg = p.bg_dark })

-- Spellchecking
hl(0, "SpellBad", { undercurl = true, sp = p.red })
hl(0, "SpellCap", { undercurl = true, sp = p.yellow })
hl(0, "SpellLocal", { undercurl = true, sp = p.blue })
hl(0, "SpellRare", { undercurl = true, sp = p.purple })

-- Signs (gutter)
hl(0, "DiagnosticSignError", { link = "DiagnosticError" })
hl(0, "DiagnosticSignWarn", { link = "DiagnosticWarn" })
hl(0, "DiagnosticSignInfo", { link = "DiagnosticInfo" })
hl(0, "DiagnosticSignHint", { link = "DiagnosticHint" })

-- Virtual text (inline)
hl(0, "DiagnosticVirtualTextError", { fg = p.red, bg = p.bg_dark })
hl(0, "DiagnosticVirtualTextWarn", { fg = p.yellow, bg = p.bg_dark })
hl(0, "DiagnosticVirtualTextInfo", { fg = p.blue, bg = p.bg_dark })
hl(0, "DiagnosticVirtualTextHint", { fg = p.cyan, bg = p.bg_dark })

-- Diagnostic floating windows
hl(0, "DiagnosticFloatingError", { link = "DiagnosticError" })
hl(0, "DiagnosticFloatingWarn", { link = "DiagnosticWarn" })
hl(0, "DiagnosticFloatingInfo", { link = "DiagnosticInfo" })
hl(0, "DiagnosticFloatingHint", { link = "DiagnosticHint" })

-- LSP-specific groups
hl(0, "LspReferenceText", { bg = p.cursorln })
hl(0, "LspReferenceRead", { bg = p.cursorln })
hl(0, "LspReferenceWrite", { bg = p.cursorln })
hl(0, "LspSignatureActiveParameter", { fg = p.yellow, italic = true })
hl(0, "LspInlayHint", { fg = p.fg_alt, bg = p.bg_dark, italic = true })
hl(0, "LspCodeLens", { fg = p.comment, italic = true })
hl(0, "LspCodeLensSeparator", { fg = p.comment })

-- Treesitter (more links)
hl(0, "@variable.builtin", { fg = p.yellow })
hl(0, "@constant.builtin", { fg = p.orange })
hl(0, "@function.builtin", { fg = p.cyan })
hl(0, "@function.macro", { fg = p.cyan })
hl(0, "@property", { fg = p.fg })
hl(0, "@field", { fg = p.fg })
hl(0, "@parameter", { fg = p.fg })
hl(0, "@keyword.function", { fg = p.purple })
hl(0, "@punctuation.bracket", { fg = p.fg })
hl(0, "@punctuation.delimiter", { fg = p.fg })

-- barbar / bufferline groups
hl(0, "BufferCurrentIndex", { link = "BufferCurrent" })
hl(0, "BufferCurrentTarget", { link = "BufferCurrent" })
hl(0, "BufferVisibleIndex", { link = "BufferVisible" })
hl(0, "BufferVisibleMod", { link = "BufferVisible" })
hl(0, "BufferVisibleTarget", { link = "BufferVisible" })
hl(0, "BufferInactiveIndex", { link = "BufferInactive" })
hl(0, "BufferInactiveMod", { link = "BufferInactive" })
hl(0, "BufferInactiveTarget", { link = "BufferInactive" })
hl(0, "BufferOffset", { fg = p.fg_alt, bg = p.bg })

-- Concealed text (e.g., markdown links when conceallevel > 0)
hl(0, "Conceal", { fg = p.comment })

-- Current search match (distinct from all matches)
hl(0, "CurSearch", { link = "IncSearch" })
hl(0, "Substitute", { fg = p.bg, bg = p.purple })

-- Substitute highlight

-- Relativenumber lines
hl(0, "LineNrAbove", { link = "LineNr" })
hl(0, "LineNrBelow", { link = "LineNr" })


hl(0, "Question", { fg = p.cyan })

-- Terminal Statuslines
hl(0, "StatusLineTerm", { link = "StatusLine" })
hl(0, "StatusLineTermNC", { link = "StatusLineNC" })

-- Kinds and extra info: keep them consistent with Pmenu/PmenuSel
hl(0, "PmenuKind", { link = "Pmenu" })
hl(0, "PmenuKindSel", { link = "PmenuSel" })
hl(0, "PmenuExtra", { link = "Pmenu" })
hl(0, "PmenuExtraSel", { link = "PmenuSel" })

-- Matched text inside completion items
hl(0, "PmenuMatch", { fg = p.yellow_light, bold = true })
hl(0, "PmenuMatchSel", { fg = p.yellow_light, bg = p.blue, bold = true })

-- Matched part of the currently inserted completion
hl(0, "ComplMatchIns", { link = "PmenuMatchSel" })

-- Wildmenu current match
hl(0, "WildMenu", { fg = p.bg, bg = p.blue, bold = true })

-- Current quickfix item
hl(0, "QuickFixLine", { fg = p.fg, bg = p.cursorln })

-- Snippet tabstops (ghost selections)
hl(0, "SnippetTabstop", { fg = p.yellow_light, bg = p.cursorln, italic = true })

-- Already have Visual; this is the "not owning selection" variant
hl(0, "VisualNOS", { link = "Visual" })

-- Titles from things like :set all, :autocmd, etc.
hl(0, "Title", { fg = p.blue_light, bold = true })

hl(0, "Directory", { fg = p.blue })

-- End of personal scheme
