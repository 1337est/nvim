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

-- basics
hl(0, "Comment", { fg = p.comment, italic = true })
hl(0, "Constant", { fg = p.cyan })
hl(0, "String", { fg = p.green })
hl(0, "Character", { fg = p.green })
hl(0, "Number", { fg = p.orange })
hl(0, "Float", { fg = p.orange })
hl(0, "Boolean", { fg = p.orange })
hl(0, "Identifier", { fg = p.blue_light })
hl(0, "Function", { fg = p.blue_dark })
hl(0, "Statement", { fg = p.purple })
hl(0, "Conditional", { fg = p.purple })
hl(0, "Repeat", { fg = p.purple })
hl(0, "Label", { fg = p.purple })
hl(0, "Operator", { fg = p.cyan })
hl(0, "Keyword", { fg = p.purple })
hl(0, "Exception", { fg = p.purple })
hl(0, "PreProc", { fg = p.red_dark })
hl(0, "Include", { fg = p.red_dark })
hl(0, "Define", { fg = p.red_dark })
hl(0, "Macro", { fg = p.red_dark })
hl(0, "PreCondit", { fg = p.red_dark })
hl(0, "Type", { fg = p.yellow_light })
hl(0, "StorageClass", { fg = p.yellow_light })
hl(0, "Structure", { fg = p.yellow_light })
hl(0, "Typedef", { fg = p.yellow_light })
hl(0, "Special", { fg = p.orange_dark })
hl(0, "SpecialChar", { fg = p.orange_dark })
hl(0, "Tag", { fg = p.orange_dark })
hl(0, "Delimiter", { fg = p.orange_dark })
hl(0, "SpecialComment", { fg = p.orange_dark })
hl(0, "Debug", { fg = p.orange_dark })
hl(0, "Underlined", { fg = p.cyan_light, underline = true })
hl(0, "Error", { fg = p.red, bold = true })
hl(0, "Todo", { fg = p.purple_dark, bold = true })
hl(0, "Added", { fg = p.green_light })
hl(0, "Changed", { fg = p.blue_light })
hl(0, "Removed", { fg = p.red_light })

-- extra flavor flave
hl(0, "ColorColumn", { bg = p.cursorln })
hl(0, "Conceal", { fg = p.comment })
hl(0, "CurSearch", { link = "IncSearch" })
hl(0, "Cursor", { reverse = true })
hl(0, "lCursor", { link = "Cursor" })
hl(0, "CursorIM", { link = "Cursor" })
hl(0, "CursorColumn", { bg = p.cursorln })
hl(0, "CursorLine", { bg = p.cursorln })
hl(0, "Directory", { fg = p.blue })
hl(0, "DiffAdd", { fg = p.green, bg = p.none })
hl(0, "DiffChange", { fg = p.yellow, bg = p.none })
hl(0, "DiffDelete", { fg = p.red, bg = p.none })
hl(0, "DiffText", { fg = p.blue, bg = p.none })
hl(0, "EndOfBuffer", { fg = p.fg, bg = p.bg_dark })
hl(0, "TermCursor", { link = "Cursor" })
hl(0, "ErrorMsg", { fg = p.red, bold = true })
hl(0, "WinSeparator", { fg = p.red_light, bg = p.orange_dark, bold = true })
hl(0, "Folded", { fg = p.yellow_dark, bg = p.bg, italic = true })
hl(0, "FoldColumn", { fg = p.yellow, bg = p.cursorln, bold = true })
hl(0, "SignColumn", { bg = p.cursorln })
hl(0, "IncSearch", { fg = p.bg, bg = p.yellow })
hl(0, "Substitute", { fg = p.bg, bg = p.purple })
hl(0, "LineNr", { fg = p.red })
hl(0, "LineNrAbove", { link = "LineNr" })
hl(0, "LineNrBelow", { link = "LineNr" })
hl(0, "CursorLineNr", { fg = p.yellow_light, bold = true })
hl(0, "CursorLineFold", { fg = p.black, bg = p.yellow, bold = true })
hl(0, "CursorLineSign", { bg = p.yellow })
hl(0, "MatchParen", { fg = p.yellow, bg = p.bg_dark, bold = true })
hl(0, "ModeMsg", { fg = p.cyan })
hl(0, "MsgArea", { fg = p.fg, bg = p.bg })
hl(0, "MsgSeparator", { fg = p.white, bg = p.bg })
hl(0, "MoreMsg", { fg = p.orange_dark, bg = p.fg_light })
hl(0, "NonText", { fg = p.gutter })
hl(0, "Normal", { fg = p.fg, bg = p.bg_light })
hl(0, "NormalFloat", { fg = p.fg_light, bg = p.bg_dark })
hl(0, "FloatBorder", { fg = p.blue, bg = p.bg_dark })
hl(0, "FloatTitle", { fg = p.yellow, bg = p.bg_dark, bold = true })
hl(0, "FloatFooter", { fg = p.orange_light, bg = p.bg, italic = true })
hl(0, "NormalNC", { fg = p.fg_light, bg = p.black })
hl(0, "Pmenu", { fg = p.fg, bg = p.bg_dark })
hl(0, "PmenuSel", { fg = p.bg, bg = p.blue })
hl(0, "PmenuKind", { link = "Pmenu" })
hl(0, "PmenuKindSel", { link = "PmenuSel" })
hl(0, "PmenuExtra", { link = "Pmenu" })
hl(0, "PmenuExtraSel", { link = "PmenuSel" })
hl(0, "PmenuSbar", { bg = p.bg_dark })
hl(0, "PmenuThumb", { bg = p.comment })
hl(0, "PmenuMatch", { fg = p.yellow_light, bold = true })
hl(0, "PmenuMatchSel", { fg = p.yellow_light, bg = p.blue, bold = true })
hl(0, "ComplMatchIns", { link = "PmenuMatchSel" })
hl(0, "Question", { fg = p.cyan })
hl(0, "QuickFixLine", { fg = p.fg, bg = p.cursorln })
hl(0, "Search", { fg = p.bg, bg = p.orange })
hl(0, "SnippetTabstop", { fg = p.yellow_light, bg = p.cursorln, italic = true })
hl(0, "SpecialKey", { fg = p.gutter })
hl(0, "SpellBad", { undercurl = true, sp = p.red })
hl(0, "SpellCap", { undercurl = true, sp = p.yellow })
hl(0, "SpellLocal", { undercurl = true, sp = p.blue })
hl(0, "SpellRare", { undercurl = true, sp = p.purple })
hl(0, "StatusLine", { fg = p.yellow, bg = p.bg_dark })
hl(0, "StatusLineNC", { fg = p.comment, bg = p.bg_dark })
hl(0, "StatusLineTerm", { link = "StatusLine" })
hl(0, "StatusLineTermNC", { link = "StatusLineNC" })
hl(0, "TabLine", { fg = p.orange_dark, bg = p.black })
hl(0, "TabLineSel", { fg = p.fg, bg = p.red, bold = true })
hl(0, "TabLineFill", { fg = p.yellow_dark, bg = p.black })
hl(0, "Title", { fg = p.blue_light, bold = true })
hl(0, "Visual", { reverse = true })
hl(0, "VisualNOS", { link = "Visual" })
hl(0, "WarningMsg", { fg = p.orange, bold = true })
hl(0, "Whitespace", { fg = p.gutter })
hl(0, "WildMenu", { fg = p.bg, bg = p.blue, bold = true })
hl(0, "WinBar", { fg = p.fg, bg = p.bg_dark })
hl(0, "WinBarNC", { fg = p.fg_alt, bg = p.bg_dark })

-- Personal highlights for my comment tags
hl(0, "1337TagTODO", { fg = p.purple_dark, bg = p.white, bold = true })
hl(0, "1337TagTEST", { fg = p.cyan_dark, bg = p.white, bold = true })
hl(0, "1337TagPASS", { fg = p.green_dark, bg = p.white, bold = true })
hl(0, "1337TagPERF", { fg = p.green_dark, bg = p.white, bold = true })
hl(0, "1337TagFAIL", { fg = p.red_dark, bg = p.white, bold = true })
hl(0, "1337TagWARN", { fg = p.orange_dark, bg = p.white, bold = true })
hl(0, "1337TagNOTE", { fg = p.blue_dark, bg = p.white, bold = true })

-- TODO: need to add
-- "User1" .. "User9", for statusline and rulerformat

-- TODO: Need to go through
-- gutter
hl(0, "GitSignsAdd", { fg = p.green_dark, bg = p.gutter })
hl(0, "GitSignsChange", { fg = p.blue_dark, bg = p.gutter })
hl(0, "GitSignsDelete", { fg = p.red_dark, bg = p.gutter })
hl(0, "VertSplit", { fg = p.bg_dark, bg = p.red })
-- diagnostics
hl(0, "DiagnosticError", { fg = p.red })
hl(0, "DiagnosticWarn", { fg = p.yellow })
hl(0, "DiagnosticInfo", { fg = p.blue })
hl(0, "DiagnosticHint", { fg = p.cyan })
hl(0, "DiagnosticUnderlineError", { undercurl = true, sp = p.red })
hl(0, "DiagnosticUnderlineWarn", { undercurl = true, sp = p.yellow })
hl(0, "DiagnosticUnderlineInfo", { undercurl = true, sp = p.blue })
hl(0, "DiagnosticUnderlineHint", { undercurl = true, sp = p.cyan })
hl(0, "DiagnosticSignError", { link = "DiagnosticError" })
hl(0, "DiagnosticSignWarn", { link = "DiagnosticWarn" })
hl(0, "DiagnosticSignInfo", { link = "DiagnosticInfo" })
hl(0, "DiagnosticSignHint", { link = "DiagnosticHint" })
hl(0, "DiagnosticVirtualTextError", { fg = p.red, bg = p.bg_dark })
hl(0, "DiagnosticVirtualTextWarn", { fg = p.yellow, bg = p.bg_dark })
hl(0, "DiagnosticVirtualTextInfo", { fg = p.blue, bg = p.bg_dark })
hl(0, "DiagnosticVirtualTextHint", { fg = p.cyan, bg = p.bg_dark })
hl(0, "DiagnosticFloatingError", { link = "DiagnosticError" })
hl(0, "DiagnosticFloatingWarn", { link = "DiagnosticWarn" })
hl(0, "DiagnosticFloatingInfo", { link = "DiagnosticInfo" })
hl(0, "DiagnosticFloatingHint", { link = "DiagnosticHint" })
-- LSP-specific groups
