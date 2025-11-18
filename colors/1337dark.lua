-- 1337dark.lua — warm onedark-ish Neovim colorscheme, structure from vim.lua

-- Base palette --------------------------------------------------
local c    = {
    none = "none",

    -- neutrals
    black = "#000000",
    gray_darkest = "#1e1e1e",
    gray_darker = "#333333",
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
    red_darkest = "#100808",
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
    orange_darkest = "#300800",
    -- brownish yellows, like djon mustard
    mustard_darkest = "#280808",
    mustard_darker = "#512a18",
    mustard_dark = "#714a09",
    mustard = "#93691d",
    mustard_light = "#b5803b",
    mustard_lighter = "#dba05c",
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
    olive_darkest = "#101000",
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
    green_darkest = "#021b04",
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
c.bg_dark  = c.bulba_darkest
c.bg       = c.blue_darkest
c.bg_light = c.cobalt_darkest
c.bg_alt   = c.blue_darker

c.fg_light = c.white
c.fg       = c.gray_lighter
c.fg_dark  = c.gray
c.fg_alt   = c.gray_light

c.comment  = c.mustard_light
c.const    = c.orange_lighter
c.string   = c.green_lighter
c.var      = c.red_lighter
c.fn       = c.cobalt_light
c.keyword  = c.purple_lighter
c.preproc  = c.purple
c.type     = c.yellow_light
c.special  = c.red_dark

c.error    = c.red
c.warn     = c.rust
c.info     = c.cyan_dark -- used also for test
c.hint     = c.cobalt
c.ok       = c.green
c.perf     = c.yellow -- gold?
c.todo     = c.purple

c.add      = c.green
c.changed  = c.orange
c.delete   = c.red

-- Reset highlights -----------------------------------------------------------
vim.cmd("highlight clear")
if vim.fn.exists("syntax_on") == 1 then vim.cmd("syntax reset") end
vim.g.colors_name = "1337dark"

local hl = function(name, val)
    -- Force links
    val.force = true

    -- Make sure that 'cterm' attributes are not populated from 'gui'
    val.cterm = val.cterm or {} ---@type vim.api.keyset.highlight

    -- Define global highlight
    vim.api.nvim_set_hl(0, name, val)
end

-- General code syntax --------------------------------------------------------------
hl("Comment", { fg = c.comment, italic = true }) -- any comment

hl("Constant", { fg = c.const }) -- any constant
hl("Number", { fg = c.const }) -- numbers
hl("Float", { fg = c.const }) -- floats
hl("Boolean", { fg = c.const }) -- TRUE, false, etc.
hl("String", { fg = c.string }) -- a string constant: "this is a string"
hl("Character", { fg = c.string }) -- a character constant: 'c', '\n'

hl("Identifier", { fg = c.var }) -- variable names
hl("Function", { fg = c.fn }) -- function names (also: methods for classes)

hl("Keyword", { fg = c.keyword }) -- keywords
hl("Statement", { fg = c.keyword }) -- any statement
hl("Conditional", { fg = c.keyword }) -- if, then, else, endif, swtich, etc.
hl("Repeat", { fg = c.keyword }) -- for, do, while, etc.
hl("Label", { fg = c.keyword }) -- case, default, etc.
hl("Operator", { fg = c.keyword }) -- sizeof, +, *, etc.
hl("Exception", { fg = c.keyword }) -- try, catch, throw

hl("PreProc", { fg = c.preproc }) -- preprocessor generics
hl("Include", { fg = c.preproc }) -- #include
hl("Define", { fg = c.preproc }) -- #define
hl("Macro", { fg = c.preproc }) -- same as Define
hl("PreCondit", { fg = c.preproc }) -- #if, #else, #endif, etc.

hl("Type", { fg = c.type }) -- int, long, char, etc.
hl("StorageClass", { fg = c.type }) -- static, register, volatile, etc.
hl("Structure", { fg = c.type }) -- struct, union, enum, etc
hl("Typedef", { fg = c.type }) -- typedef

hl("Special", { fg = c.special }) -- special symbols - table {} in lua
hl("SpecialChar", { fg = c.special }) -- special characters in a constant '\n'
hl("Tag", { fg = c.special }) -- like html/xml tags
hl("SpecialComment", { fg = c.special }) -- special things inside comments
hl("Debug", { fg = c.special }) -- debug statements
hl("Delimiter", { fg = c.yellow_light }) -- character that needs attention

hl("Underlined", { fg = c.cyan_light, underline = true }) -- like HTML links

hl("Todo", { fg = c.todo, bg = c.white, bold = true }) -- TODO FIXME XXX

hl("DiffText", { fg = c.fg })
hl("Added", { fg = c.add }) -- Added line in a diff
hl("DiffAdd", { fg = c.add })
hl("Changed", { fg = c.orange }) -- Changed line in a diff
hl("DiffChange", { fg = c.changed })
hl("Removed", { fg = c.red }) -- Removed line in a diff
hl("DiffDelete", { fg = c.delete })

-- General Syntax --------------------------------------------------------------

hl("Normal", { fg = c.fg, bg = c.bg })
hl("NormalNC", { fg = c.fg_alt, bg = c.bg_light })
hl("NormalFloat", { fg = c.fg, bg = c.bg_dark })
hl("EndOfBuffer", { fg = c.orange_light, bg = c.olive_darkest })

hl("FloatBorder", { fg = c.cobalt, bg = c.bg_dark })
hl("FloatTitle", { fg = c.yellow, bg = c.bg_dark, bold = true })
hl("FloatFooter", { fg = c.orange_light, bg = c.bg_dark, italic = true })

hl("ColorColumn", { bg = c.bulba_darkest }) -- used for colors set with colorcolumn

hl("IncSearch", { fg = c.bg, bg = c.yellow })
hl("CurSearch", { link = "IncSearch" }) -- current match for the last search
hl("Substitute", { fg = c.bg, bg = c.purple_lighter })
hl("MatchParen", { fg = c.yellow_light, bg = c.bg_dark, bold = true })

hl("Conceal", { fg = c.gray }) -- placeholder characters subbed for concealed text

hl("Directory", { fg = c.cobalt_light })

hl("Cursor", { fg = c.bg, bg = c.fg }) -- character under the cursor
hl("lCursor", { link = "Cursor" })
hl("CursorIM", { link = "Cursor" })
hl("TermCursor", { link = "Cursor" })
hl("CursorColumn", { bg = c.gray })
hl("CursorLine", { bg = c.gray })

-- UI / editor ----------------------------------------------------------------

hl("WinSeparator", { fg = c.yellow, bg = c.yellow_darkest })
hl("Folded", { fg = c.orange_dark, bg = c.yellow_lighter, italic = true })
hl("FoldColumn", { fg = c.yellow, bg = c.cyan_darkest, bold = true })
hl("SignColumn", { bg = c.black })
hl("LineNr", { fg = c.orange_light, bg = c.bg_alt })
hl("LineNrAbove", { link = "LineNr" })
hl("LineNrBelow", { link = "LineNr" })
hl("CursorLineNr", { fg = c.yellow_light, bold = true })
hl("CursorLineFold", { fg = c.black, bg = c.yellow, bold = true })
hl("CursorLineSign", { bg = c.bg })

hl("ModeMsg", { fg = c.cyan })
hl("MsgArea", { fg = c.fg, bg = c.bg })
hl("MsgSeparator", { fg = c.white, bg = c.bg })
hl("MoreMsg", { fg = c.orange_light, bg = c.bg })

hl("NonText", { fg = c.red })
hl("SpecialKey", { fg = c.red })
hl("Whitespace", { fg = c.fg })

hl("Pmenu", { fg = c.fg, bg = c.bg_dark })
hl("PmenuSel", { fg = c.bg, bg = c.cobalt })
hl("PmenuKind", { link = "Pmenu" })
hl("PmenuKindSel", { link = "PmenuSel" })
hl("PmenuExtra", { link = "Pmenu" })
hl("PmenuExtraSel", { link = "PmenuSel" })
hl("PmenuSbar", { bg = c.bg_dark })
hl("PmenuThumb", { bg = c.comment })
hl("PmenuMatch", { fg = c.yellow_light, bold = true })
hl("PmenuMatchSel", { fg = c.yellow_light, bg = c.cobalt, bold = true })
hl("ComplMatchIns", { link = "PmenuMatchSel" })

hl("Question", { fg = c.cyan })
hl("QuickFixLine", { fg = c.fg, bg = c.gray })

hl("Search", { fg = c.bg, bg = c.orange })
hl("SnippetTabstop", { fg = c.yellow_light, bg = c.gray, italic = true })

hl("SpellBad", { undercurl = true, sp = c.red })
hl("SpellCap", { undercurl = true, sp = c.yellow })
hl("SpellLocal", { undercurl = true, sp = c.cobalt })
hl("SpellRare", { undercurl = true, sp = c.purple })

hl("StatusLine", { fg = c.yellow, bg = c.yellow_darkest })
hl("StatusLineNC", { fg = c.comment, bg = c.bg_dark })
hl("StatusLineTerm", { link = "StatusLine" })
hl("StatusLineTermNC", { link = "StatusLineNC" })

hl("TabLine", { fg = c.fg_light, bg = c.gray_darker })
hl("TabLineSel", { fg = c.orange_darker, bg = c.yellow_darker, bold = true })
hl("TabLineFill", { fg = c.yellow, bg = c.yellow_darkest })

hl("Title", { fg = c.yellow, bg = c.cobalt_darkest, bold = true })

hl("Visual", { bg = c.mustard_darker }) -- selection
hl("VisualNOS", { link = "Visual" })

hl("WarningMsg", { fg = c.orange, bold = true })
hl("WildMenu", { fg = c.bg, bg = c.cobalt, bold = true })

hl("WinBar", { fg = c.rust_darkest, bg = c.yellow })
hl("WinBarNC", { fg = c.yellow, bg = c.bg })

-- Diagnostics ----------------------------------------------------------------
hl("Error", { fg = c.error, bold = true })
hl("ErrorMsg", { fg = c.error, bold = true })

hl("DiagnosticError", { fg = c.error })
hl("DiagnosticVirtualTextError", { fg = c.error, bg = c.bg_dark })
hl("DiagnosticVirtualLinesError", { fg = c.error, bg = c.bg_dark })
hl("DiagnosticUnderlineError", { undercurl = true, sp = c.error })
hl("DiagnosticFloatingError", { link = "DiagnosticError" })
hl("DiagnosticSignError", { link = "DiagnosticError" })

hl("DiagnosticWarn", { fg = c.warn })
hl("DiagnosticVirtualTextWarn", { fg = c.warn, bg = c.bg_dark })
hl("DiagnosticVirtualLinesWarn", { fg = c.warn, bg = c.bg_dark })
hl("DiagnosticUnderlineWarn", { undercurl = true, sp = c.warn })
hl("DiagnosticFloatingWarn", { link = "DiagnosticWarn" })
hl("DiagnosticSignWarn", { link = "DiagnosticWarn" })

hl("DiagnosticInfo", { fg = c.info })
hl("DiagnosticVirtualTextInfo", { fg = c.info, bg = c.bg_dark })
hl("DiagnosticVirtualLinesInfo", { fg = c.info, bg = c.bg_dark })
hl("DiagnosticUnderlineInfo", { undercurl = true, sp = c.info })
hl("DiagnosticFloatingInfo", { link = "DiagnosticInfo" })
hl("DiagnosticSignInfo", { link = "DiagnosticInfo" })

hl("DiagnosticHint", { fg = c.hint })
hl("DiagnosticVirtualTextHint", { fg = c.hint, bg = c.bg_dark })
hl("DiagnosticVirtualLinesHint", { fg = c.hint, bg = c.bg_dark })
hl("DiagnosticUnderlineHint", { undercurl = true, sp = c.hint })
hl("DiagnosticFloatingHint", { link = "DiagnosticHint" })
hl("DiagnosticSignHint", { link = "DiagnosticHint" })

hl("DiagnosticOk", { fg = c.ok })
hl("DiagnosticVirtualTextOk", { fg = c.ok, bg = c.bg_dark })
hl("DiagnosticVirtualLinesOk", { fg = c.ok, bg = c.bg_dark })
hl("DiagnosticUnderlineOk", { undercurl = true, sp = c.ok })
hl("DiagnosticFloatingOk", { link = "DiagnosticOk" })
hl("DiagnosticSignOk", { link = "DiagnosticOk" })

hl("DiagnosticDeprecated", { strikethrough = true })
hl("DiagnosticUnnecessary", { link = "Comment" })

-- Personal comment tags ------------------------------------------------------
hl("1337TagTODO", { fg = c.purple_dark, bg = c.white, bold = true })
hl("1337TagTEST", { fg = c.cyan_dark, bg = c.white, bold = true })
hl("1337TagPASS", { fg = c.green_dark, bg = c.white, bold = true })
hl("1337TagPERF", { fg = c.green_dark, bg = c.white, bold = true })
hl("1337TagFAIL", { fg = c.error, bg = c.white, bold = true })
hl("1337TagWARN", { fg = c.warn, bg = c.white, bold = true })
hl("1337TagNOTE", { fg = c.cobalt_dark, bg = c.white, bold = true })

-- User1..7 (for your statusline mode segment) --------------------------------
hl("User1", { fg = c.black, bg = c.blue, bold = true }) -- normal
hl("User2", { fg = c.black, bg = c.orange, bold = true }) -- visual
hl("User3", { fg = c.black, bg = c.rust_lighter, bold = true }) -- select
hl("User4", { fg = c.black, bg = c.green_dark, bold = true }) -- insert
hl("User5", { fg = c.black, bg = c.purple, bold = true }) -- replace
hl("User6", { fg = c.black, bg = c.red, bold = true }) -- command
hl("User7", { fg = c.black, bg = c.yellow, bold = true }) -- terminal
