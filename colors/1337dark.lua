-- 1337dark.lua — warm onedark-ish Neovim colorscheme

local hl   = vim.api.nvim_set_hl

-- Base palette --------------------------------------------------
local c    = {
    none = "none",

    -- neutrals
    black = "#000000",
    gray_darker = "#1e1e1e",
    gray_dark = "#2a2a2a",
    gray = "#5c5c5c",
    gray_light = "#a0a0a0",
    gray_lighter = "#d0d0d0",
    white = "#ffffff",
    -- reds (warm and toasty)
    red_lighter = "#ff7772",
    red_light = "#f05c55",
    red = "#f63b34",
    red_dark = "#f42924",
    red_darker = "#fb020c",
    red_darkest = "#200808",
    -- red / orange / rust-colored
    rust_lighter = "#e58c6b",
    rust_light = "#d57a5e",
    rust = "#c2684f",
    rust_dark = "#9f523f",
    rust_darker = "#7a3f31",
    rust_darkest = "#401010",
    -- oranges (yum)
    orange_lighter = "#ffcc00",
    orange_light = "#ffaa00",
    orange = "#ff8800",
    orange_dark = "#ff6600",
    orange_darker = "#ff4400",
    orange_darkest = "#180800",
    -- yellows / golds (I like GOOOooolldd)
    yellow_lighter = "#f2f9ba",
    yellow_light = "#f5f07b",
    yellow = "#f1fa65",
    yellow_dark = "#e8e25d",
    yellow_darker = "#c3c32a",
    yellow_darkest = "#202000",
    -- olives (the color of olives)
    olive_lighter = "#d0d68b",
    olive_light = "#b5bf72",
    olive = "#99a35e",
    olive_dark = "#7a8548",
    olive_darker = "#5a6235",
    olive_darkest = "#102000",
    -- bulba (sauuuurrr, light greenery with dino genes)
    bulba_lighter = "#c4f8e1",
    bulba_light = "#aedbc0",
    bulba = "#87bcae",
    bulba_dark = "#65978f",
    bulba_darker = "#467d67",
    bulba_darkest = "#102020",
    -- greens
    green_lighter = "#a0e085",
    green_light = "#85c36d",
    green = "#6fae47",
    green_dark = "#43892b",
    green_darker = "#226609",
    -- cyans / teals
    cyan_lighter = "#6fd3dd",
    cyan_light = "#57c0ca",
    cyan = "#46b6c2",
    cyan_dark = "#3f8f9b",
    cyan_darker = "#295e63",
    cyan_darkest = "#081820",
    -- steel / cobalt blues
    cobalt_lighter = "#7fc4ff",
    cobalt_light = "#61afdf",
    cobalt = "#4a8fac",
    cobalt_dark = "#38728a",
    cobalt_darker = "#264a50",
    cobalt_darkest = "#04100f",
    -- deeper blues
    blue_lighter = "#6aa2f7",
    blue_light = "#4f84d3",
    blue = "#3b6bb5",
    blue_dark = "#284f86",
    blue_darker = "#17355a",
    blue_darkest = "#040410",
    -- purples / magenta
    purple_lighter = "#d4a1e9",
    purple_light = "#c678dd",
    purple = "#a761c4",
    purple_dark = "#844a9c",
    purple_darker = "#5c326e",
    purple_darkest = "#100810",
}

-- semantic aliases ----------------------
c.bg       = c.bulba_darkest
c.bg_dark  = c.blue_darkest
c.bg_light = c.cobalt_darkest

c.fg       = c.gray_lighter
c.fg_light = c.white
c.fg_dark  = c.gray
c.fg_alt   = c.gray_light

c.comment  = c.yellow_lighter
c.gutter   = c.orange_light
c.cursorln = c.cobalt_darker

-- Reset highlights -----------------------------------------------------------
vim.cmd("highlight clear")
if vim.fn.exists("syntax_on") == 1 then vim.cmd("syntax reset") end
vim.g.colors_name = "1337dark"

-- Syntax ---------------------------------------------------------------------
hl(0, "Normal", { fg = c.fg, bg = c.bg })
hl(0, "NormalNC", { fg = c.fg_alt, bg = c.bg_dark })
hl(0, "NormalFloat", { fg = c.fg, bg = c.bg_dark })

hl(0, "Comment", { fg = c.comment, italic = true }) -- any comment

hl(0, "Constant", { fg = c.cyan }) -- any constant
hl(0, "String", { fg = c.green_lighter }) -- a string constant: "this is a string"
hl(0, "Character", { fg = c.green_lighter }) -- a character constant: 'c', '\n'
hl(0, "Number", { fg = c.orange_lighter }) -- numbers
hl(0, "Float", { fg = c.orange_lighter }) -- floats
hl(0, "Boolean", { fg = c.orange_lighter }) -- TRUE, false, etc.

hl(0, "Identifier", { fg = c.cobalt_lighter }) -- variable names
hl(0, "Function", { fg = c.cobalt }) -- function names (also: methods for classes)

hl(0, "Statement", { fg = c.purple }) -- any statement
hl(0, "Conditional", { fg = c.purple }) -- if, then, else, endif, swtich, etc.
hl(0, "Repeat", { fg = c.purple }) -- for, do, while, etc.
hl(0, "Label", { fg = c.purple }) -- case, default, etc.
hl(0, "Operator", { fg = c.purple }) -- sizeof, +, *, etc.
hl(0, "Keyword", { fg = c.purple_light }) -- other keywords
hl(0, "Exception", { fg = c.purple }) -- try, catch, throw

hl(0, "PreProc", { fg = c.red_dark }) -- preprocessor generics
hl(0, "Include", { fg = c.red_dark }) -- #include
hl(0, "Define", { fg = c.red_dark }) -- #define
hl(0, "Macro", { fg = c.red_dark }) -- same as Define
hl(0, "PreCondit", { fg = c.red_dark }) -- #if, #else, #endif, etc.

hl(0, "Type", { fg = c.yellow_light }) -- int, long, char, etc.
hl(0, "StorageClass", { fg = c.yellow_light }) -- static, register, volatile, etc.
hl(0, "Structure", { fg = c.yellow_light }) -- struct, union, enum, etc
hl(0, "Typedef", { fg = c.yellow_light }) -- typedef

hl(0, "Special", { fg = c.orange_dark }) -- special symbols
hl(0, "SpecialChar", { fg = c.orange_dark }) -- special characters in a constant '\n'
hl(0, "Tag", { fg = c.orange_dark }) -- You can use CTRL-] on this
hl(0, "Delimiter", { fg = c.orange_dark }) -- character that needs attention
hl(0, "SpecialComment", { fg = c.orange_dark }) -- special things inside comments
hl(0, "Debug", { fg = c.orange_dark }) -- debug statements

hl(0, "Underlined", { fg = c.cyan_light, underline = true }) -- like HTML links

hl(0, "Todo", { fg = c.purple_dark, bg = c.white, bold = true }) -- TODO FIXME XXX

hl(0, "Added", { fg = c.green_light }) -- Added line in a diff
hl(0, "Changed", { fg = c.cobalt_lighter }) -- Changed line in a diff
hl(0, "Removed", { fg = c.red_light }) -- Removed line in a diff

-- UI / editor ----------------------------------------------------------------
hl(0, "ColorColumn", { bg = c.orange_lighter }) -- used for colors set with colorcolumn
hl(0, "Conceal", { fg = c.comment }) -- placeholder characters subbed for concealed text
hl(0, "CurSearch", { link = "IncSearch" }) -- current match for the last search

hl(0, "Cursor", { fg = c.bg, bg = c.fg }) -- character under the cursor
hl(0, "lCursor", { link = "Cursor" })
hl(0, "CursorIM", { link = "Cursor" })

hl(0, "CursorColumn", { bg = c.cursorln })
hl(0, "CursorLine", { bg = c.cursorln })

hl(0, "Directory", { fg = c.cobalt })
hl(0, "DiffAdd", { fg = c.green_light, bg = c.none })
hl(0, "DiffChange", { fg = c.yellow, bg = c.none })
hl(0, "DiffDelete", { fg = c.red, bg = c.none })
hl(0, "DiffText", { fg = c.cobalt_lighter, bg = c.none })

hl(0, "TermCursor", { link = "Cursor" })

hl(0, "WinSeparator", { fg = c.yellow, bg = c.yellow_darkest })
hl(0, "Folded", { fg = c.orange_dark, bg = c.yellow_lighter, italic = true })
hl(0, "FoldColumn", { fg = c.yellow, bg = c.cyan_darkest, bold = true })
hl(0, "SignColumn", { bg = c.black })

hl(0, "IncSearch", { fg = c.bg, bg = c.yellow })
hl(0, "Substitute", { fg = c.bg, bg = c.purple })

hl(0, "LineNr", { fg = c.gutter, bg = c.blue_darker })
hl(0, "EndOfBuffer", { fg = c.gutter, bg = c.bg_light })
hl(0, "LineNrAbove", { link = "LineNr" })
hl(0, "LineNrBelow", { link = "LineNr" })
hl(0, "CursorLineNr", { fg = c.yellow_light, bold = true })
hl(0, "CursorLineFold", { fg = c.black, bg = c.yellow, bold = true })
hl(0, "CursorLineSign", { bg = c.bg })

hl(0, "MatchParen", { fg = c.yellow_light, bg = c.bg_dark, bold = true })

hl(0, "ModeMsg", { fg = c.cyan })
hl(0, "MsgArea", { fg = c.fg, bg = c.bg })
hl(0, "MsgSeparator", { fg = c.white, bg = c.bg })
hl(0, "MoreMsg", { fg = c.orange_light, bg = c.bg })

hl(0, "NonText", { fg = c.gutter })
hl(0, "SpecialKey", { fg = c.gutter })
hl(0, "Whitespace", { fg = c.gutter })

hl(0, "FloatBorder", { fg = c.cobalt, bg = c.bg_dark })
hl(0, "FloatTitle", { fg = c.yellow, bg = c.bg_dark, bold = true })
hl(0, "FloatFooter", { fg = c.orange_light, bg = c.bg_dark, italic = true })

hl(0, "Pmenu", { fg = c.fg, bg = c.bg_dark })
hl(0, "PmenuSel", { fg = c.bg, bg = c.cobalt })
hl(0, "PmenuKind", { link = "Pmenu" })
hl(0, "PmenuKindSel", { link = "PmenuSel" })
hl(0, "PmenuExtra", { link = "Pmenu" })
hl(0, "PmenuExtraSel", { link = "PmenuSel" })
hl(0, "PmenuSbar", { bg = c.bg_dark })
hl(0, "PmenuThumb", { bg = c.comment })
hl(0, "PmenuMatch", { fg = c.yellow_light, bold = true })
hl(0, "PmenuMatchSel", { fg = c.yellow_light, bg = c.cobalt, bold = true })
hl(0, "ComplMatchIns", { link = "PmenuMatchSel" })

hl(0, "Question", { fg = c.cyan })
hl(0, "QuickFixLine", { fg = c.fg, bg = c.cursorln })

hl(0, "Search", { fg = c.bg, bg = c.orange })
hl(0, "SnippetTabstop", { fg = c.yellow_light, bg = c.cursorln, italic = true })

hl(0, "SpellBad", { undercurl = true, sp = c.red })
hl(0, "SpellCap", { undercurl = true, sp = c.yellow })
hl(0, "SpellLocal", { undercurl = true, sp = c.cobalt })
hl(0, "SpellRare", { undercurl = true, sp = c.purple })

hl(0, "StatusLine", { fg = c.yellow, bg = c.yellow_darkest })
hl(0, "StatusLineNC", { fg = c.comment, bg = c.bg_dark })
hl(0, "StatusLineTerm", { link = "StatusLine" })
hl(0, "StatusLineTermNC", { link = "StatusLineNC" })

hl(0, "TabLine", { fg = c.fg_light, bg = c.gray_darker })
hl(0, "TabLineSel", { fg = c.orange_darker, bg = c.yellow_darker, bold = true })
hl(0, "TabLineFill", { fg = c.yellow, bg = c.yellow_darkest })

hl(0, "Title", { fg = c.yellow, bg = c.cobalt_darkest, bold = true })

hl(0, "Visual", { bg = c.gray }) -- selection
hl(0, "VisualNOS", { link = "Visual" })

hl(0, "WarningMsg", { fg = c.orange, bold = true })
hl(0, "WildMenu", { fg = c.bg, bg = c.cobalt, bold = true })

hl(0, "WinBar", { fg = c.rust_darkest, bg = c.yellow })
hl(0, "WinBarNC", { fg = c.yellow, bg = c.bg })

-- Diagnostics ----------------------------------------------------------------
hl(0, "Error", { fg = c.red, bold = true })
hl(0, "ErrorMsg", { fg = c.red, bold = true })

hl(0, "DiagnosticError", { fg = c.red })
hl(0, "DiagnosticVirtualTextError", { fg = c.red, bg = c.bg_dark })
hl(0, "DiagnosticVirtualLinesError", { fg = c.red, bg = c.bg_dark })
hl(0, "DiagnosticUnderlineError", { undercurl = true, sp = c.red })
hl(0, "DiagnosticFloatingError", { link = "DiagnosticError" })
hl(0, "DiagnosticSignError", { link = "DiagnosticError" })

hl(0, "DiagnosticWarn", { fg = c.yellow })
hl(0, "DiagnosticVirtualTextWarn", { fg = c.yellow, bg = c.bg_dark })
hl(0, "DiagnosticVirtualLinesWarn", { fg = c.yellow, bg = c.bg_dark })
hl(0, "DiagnosticUnderlineWarn", { undercurl = true, sp = c.yellow })
hl(0, "DiagnosticFloatingWarn", { link = "DiagnosticWarn" })
hl(0, "DiagnosticSignWarn", { link = "DiagnosticWarn" })

hl(0, "DiagnosticInfo", { fg = c.cyan })
hl(0, "DiagnosticVirtualTextInfo", { fg = c.cyan, bg = c.bg_dark })
hl(0, "DiagnosticVirtualLinesInfo", { fg = c.cyan, bg = c.bg_dark })
hl(0, "DiagnosticUnderlineInfo", { undercurl = true, sp = c.cyan })
hl(0, "DiagnosticFloatingInfo", { link = "DiagnosticInfo" })
hl(0, "DiagnosticSignInfo", { link = "DiagnosticInfo" })

hl(0, "DiagnosticHint", { fg = c.cobalt })
hl(0, "DiagnosticVirtualTextHint", { fg = c.cobalt, bg = c.bg_dark })
hl(0, "DiagnosticVirtualLinesHint", { fg = c.cobalt, bg = c.bg_dark })
hl(0, "DiagnosticUnderlineHint", { undercurl = true, sp = c.cobalt })
hl(0, "DiagnosticFloatingHint", { link = "DiagnosticHint" })
hl(0, "DiagnosticSignHint", { link = "DiagnosticHint" })

hl(0, "DiagnosticOk", { fg = c.green_light })
hl(0, "DiagnosticVirtualTextOk", { fg = c.green_light, bg = c.bg_dark })
hl(0, "DiagnosticVirtualLinesOk", { fg = c.green_light, bg = c.bg_dark })
hl(0, "DiagnosticUnderlineOk", { undercurl = true, sp = c.green_light })
hl(0, "DiagnosticFloatingOk", { link = "DiagnosticOk" })
hl(0, "DiagnosticSignOk", { link = "DiagnosticOk" })

hl(0, "DiagnosticDeprecated", { strikethrough = true })
hl(0, "DiagnosticUnnecessary", { link = "Comment" })

-- User1..7 (for your statusline mode segment) --------------------------------
hl(0, "User1", { fg = c.black, bg = c.blue, bold = true }) -- normal
hl(0, "User2", { fg = c.black, bg = c.orange, bold = true }) -- visual
hl(0, "User3", { fg = c.black, bg = c.rust_lighter, bold = true }) -- select
hl(0, "User4", { fg = c.black, bg = c.green_dark, bold = true }) -- insert
hl(0, "User5", { fg = c.black, bg = c.purple, bold = true }) -- replace
hl(0, "User6", { fg = c.black, bg = c.red, bold = true }) -- command
hl(0, "User7", { fg = c.black, bg = c.yellow, bold = true }) -- terminal

-- Personal comment tags ------------------------------------------------------
hl(0, "1337TagTODO", { fg = c.purple_dark, bg = c.white, bold = true })
hl(0, "1337TagTEST", { fg = c.cyan_dark, bg = c.white, bold = true })
hl(0, "1337TagPASS", { fg = c.green_dark, bg = c.white, bold = true })
hl(0, "1337TagPERF", { fg = c.green_dark, bg = c.white, bold = true })
hl(0, "1337TagFAIL", { fg = c.red_dark, bg = c.white, bold = true })
hl(0, "1337TagWARN", { fg = c.orange_dark, bg = c.white, bold = true })
hl(0, "1337TagNOTE", { fg = c.cobalt_dark, bg = c.white, bold = true })
