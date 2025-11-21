-- 1337dark.lua — My Personal Neovim Colorscheme

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
    gray_lightest = "#eeeeee",
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

c.fg       = c.gray_lighter
c.fg_dark  = c.gray
c.fg_alt   = c.gray_light

c.comment  = c.mustard_lighter
c.const    = c.cyan
c.num      = c.yellow
c.string   = c.green_light
c.var      = c.red_lighter
c.fn       = c.cobalt_light
c.keyword  = c.red
c.preproc  = c.purple
c.type     = c.orange_dark

c.error    = c.red
c.warn     = c.orange
c.info     = c.cyan_dark -- used also for test
c.hint     = c.cobalt_dark
c.ok       = c.green
c.perf     = c.yellow_darker -- gold?
c.todo     = c.purple
c.test     = c.blue

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
    val.cterm = val.cterm or {} --- @type vim.api.keyset.highlight

    -- Define global highlight
    vim.api.nvim_set_hl(0, name, val)
end

-- General code syntax --------------------------------------------------------------
hl("Comment", { fg = c.comment, italic = true }) -- any comment
hl("@comment", { link = "Comment" }) -- line and block comments
hl("@string.documentation", { link = "Comment" }) -- string documentation e.g. Python docstrings
hl("@comment.documentation", { link = "Comment" }) -- comments documenting code
hl("@markup.quote", { link = "Comment" }) -- md block quotes
hl("SpecialComment", { fg = c.comment, underline = true }) -- special things inside comments

hl("Constant", { fg = c.const }) -- any constant cyan
hl("@constant", { link = "Constant" }) -- constant identifiers
hl("@constant.builtin", { fg = c.const, italic = true }) -- built-int constant values

hl("Number", { fg = c.num }) -- numbers
hl("@number", { link = "Number" }) -- numeric literals
hl("Float", { link = "Number" }) -- floats
hl("Boolean", { link = "Number" }) -- TRUE, false, etc.
hl("@number.float", { link = "Float" }) -- floating-point numberl iterals
hl("@boolean", { link = "Boolean" }) -- boolean literals

hl("String", { fg = c.string }) -- a string constant: "this is a string"
hl("Character", { link = "String" }) -- a character constant: 'c', '\n'
hl("@string", { link = "String" }) -- string literals
hl("@character", { link = "Character" }) -- character literals

hl("Identifier", { fg = c.var }) -- variable names
hl("@variable", { link = "Identifier" }) -- various variable names
hl("@variable.parameter", { link = "Identifier" }) -- parameters of a function
hl("@variable.member", { link = "Identifier" }) -- object / struct fields FIEELLDSSS
hl("@property", { link = "Identifier" }) -- keys in key/value pairs the key in key/value pairs
hl("@variable.builtin", { fg = c.var, italic = true }) -- e.g. this, self
hl("@variable.parameter.builtin", { fg = c.var, italic = true }) -- e.g. _, it

hl("Function", { fg = c.fn }) -- function names (also: methods for classes)
hl("@function", { link = "Function" }) -- function definitions
hl("@function.call", { link = "Function" }) -- function calls
hl("@function.method", { link = "Function" }) -- method definitions
hl("@function.method.call", { link = "Function" }) -- method calls
hl("@function.builtin", { fg = c.fn, italic = true }) -- built-in functions
hl("@constructor", { fg = c.fn, bold = true }) -- constructor calls and definitions

hl("Keyword", { fg = c.keyword }) -- keywords
hl("@keyword", { link = "Keyword" }) -- keywords not fitting into specific categories
hl("@keyword.function", { link = "Keyword" }) -- keywords that define a function e.g. func in GO, def in Python
hl("Statement", { link = "Keyword" }) -- any statement
hl("Conditional", { link = "Keyword" }) -- if, then, else, endif, swtich, etc.
hl("Repeat", { link = "Keyword" }) -- for, do, while, etc.
hl("Label", { link = "Keyword" }) -- case, default, etc.
hl("Operator", { link = "Keyword" }) -- sizeof, +, *, etc.
hl("Exception", { link = "Keyword" }) -- try, catch, throw
hl("@keyword.conditional", { link = "Conditional" }) -- if, else
hl("@keyword.repeat", { link = "Repeat" }) -- for, while
hl("@label", { link = "Label" }) -- GOTO and other label:'s in C, including heredoc labels
hl("@operator", { link = "Operator" }) -- symbolic operators e.g. +, *
hl("@keyword.conditional.ternary", { link = "Operator" }) -- ?, :
hl("@keyword.operator", { link = "Operator" }) -- Operators that are english words e.g. and, or
hl("@keyword.exception", { link = "Exception" }) -- throw, catch
hl("@keyword.coroutine", { fg = c.keyword, italic = true }) -- keywords related to coroutines e.g. go in GO, async/await in Python
hl("@keyword.modifier", { fg = c.keyword, italic = true }) -- const, static, public
hl("@keyword.return", { fg = c.keyword, bold = true }) -- return, yield

hl("PreProc", { fg = c.preproc }) -- preprocessor generics
hl("Include", { link = "PreProc" }) -- #include
hl("@keyword.directive", { link = "PreProc" }) -- various preprocessor directives and shebang bang's
hl("Define", { link = "PreProc" }) -- #define
hl("Macro", { link = "PreProc" }) -- same as Define
hl("PreCondit", { link = "PreProc" }) -- #if, #else, #endif, etc.
hl("@attribute", { link = "PreProc" }) -- attribute annotations (e.g. Python decorators, Rust lifetimes)
hl("@keyword.import", { link = "Include" }) -- keywords for including or exporting modules e.g. import, from in Python
hl("@keyword.directive.define", { link = "Define" }) -- preprocessor definition directives
hl("@constant.macro", { fg = c.preproc, underline = true }) -- constants defined by the preprocessor
hl("@function.macro", { fg = c.preproc, underline = true }) -- preprocessor macros
hl("@attribute.builtin", { fg = c.preproc, italic = true }) -- builtin annotations (e.g. `@property` in Python)

hl("Type", { fg = c.type }) -- int, long, char, etc.
hl("@type", { link = "Type" }) -- type or class definition and annotations
hl("StorageClass", { link = "Type" }) -- static, register, volatile, etc.
hl("Structure", { link = "Type" }) -- struct, union, enum, etc
hl("@keyword.type", { link = "Type" }) -- namespaces and composite types e.g. struct, enum
hl("Typedef", { link = "Type" }) -- typedef
hl("@module", { link = "Structure" }) -- modules / namespaces
hl("@type.definition", { link = "Typedef" }) -- Identifiers in type definitions typedef <type> <identifier> in C
hl("@type.builtin", { fg = c.type, italic = true }) -- built-in types
hl("@module.builtin", { fg = c.type, italic = true }) -- built-in modules / namespaces

hl("Special", { fg = c.num }) -- special symbols - table {} in lua
hl("@punctuation.special", { link = "Special" }) -- special symbols e.g. {} in string interpolation
hl("SpecialChar", { link = "Special" }) -- special characters in a constant '\n'
hl("@character.special", { link = "SpecialChar" }) -- special characters e.g. wildcards
hl("@string.regexp", { fg = c.red }) -- regular expressions
hl("@string.escape", { link = "SpecialChar" }) -- escape sequences
hl("@string.special", { link = "SpecialChar" }) -- Other special string (dates and such)
hl("@string.special.symbol", { link = "SpecialChar" }) -- symbols or atoms
hl("@string.special.path", { link = "SpecialChar" }) -- filenames

hl("Tag", { fg = c.cobalt_light }) -- like html/xml tags
hl("@tag", { link = "Tag" }) -- XML-style tag names e.g. XML, HTML, etc.
hl("@tag.builtin", { fg = c.cobalt_light, italic = true }) -- builtin tag names (HTML5 tags)
hl("@tag.attribute", { fg = c.mustard_lighter }) -- XML-style tag attributes
hl("@tag.delimiter", { fg = c.fg_alt }) -- XML-style tag delimiters

hl("Debug", { fg = c.warn }) -- debug statements
hl("@keyword.debug", { link = "Debug" }) -- keywords related to debugging

hl("Delimiter", { fg = c.num }) -- character that needs attention
hl("@punctuation.delimiter", { link = "Delimiter" }) -- ; . ,
hl("@punctuation.bracket", { link = "Delimiter" }) -- () {} [] -- (), {}, []
hl("@markup.math", { link = "Delimiter" }) -- md math environments (e.g. $ ... $ in LaTeX)

hl("Underlined", { fg = c.cyan_light, underline = true }) -- like HTML links
hl("@string.special.url", { link = "Underlined" }) -- URIs e.g. hyperlinks
hl("@markup.link", { link = "Underlined" }) -- md text references, footnotes, citations, etc.
hl("@markup.link.label", { link = "Underlined" }) -- md link, reference descriptions
hl("@markup.link.url", { link = "Underlined" }) -- md URL-style links

hl("Todo", { fg = c.todo, bg = c.white, bold = true }) -- TODO FIXME XXX

hl("DiffText", { fg = c.black, bg = c.changed }) -- Diff mode: Changed text in a diff
hl("Added", { fg = c.add }) -- Added line in a diff
hl("Changed", { fg = c.changed }) -- Changed line in a diff
hl("Removed", { fg = c.delete }) -- Removed line in a diff
hl("DiffAdd", { fg = c.black, bg = c.add }) -- Diff mode: Added line
hl("DiffChange", { fg = c.changed, underline = true }) -- Diff mode: Changed line
hl("DiffDelete", { fg = c.black, bg = c.delete }) -- Diff mode: deleted line
hl("@diff.plus", { link = "DiffAdd" }) -- added text for diff files
hl("@diff.delta", { link = "DiffChange" }) -- changed text for diff files
hl("@diff.minus", { link = "DiffDelete" }) -- deleted text for diff files

-- General Syntax --------------------------------------------------------------

hl("Normal", { fg = c.fg, bg = c.bg })
hl("NormalNC", { fg = c.fg_alt, bg = c.bg_dark })
hl("NormalFloat", { fg = c.fg, bg = c.bg })
hl("EndOfBuffer", { fg = c.orange_light, bg = c.purple_darkest })
hl("Title", { fg = c.yellow, bg = c.bg_dark, bold = true })

hl("FloatBorder", { fg = c.cobalt, bg = c.bg_dark })
hl("FloatTitle", { link = "Title" })
hl("FloatFooter", { fg = c.orange_light, bg = c.bg_dark, italic = true })

hl("ColorColumn", { bg = c.bulba_darkest })

hl("Search", { fg = c.bg_alt, bg = c.yellow_lighter })
hl("IncSearch", { fg = c.black, bg = c.orange_lighter })
hl("CurSearch", { link = "IncSearch" }) -- current match for the last search
hl("Substitute", { fg = c.bg, bg = c.purple_lighter })
hl("MatchParen", { fg = c.black, bg = c.orange, underline = true })

hl("WildMenu", { fg = c.bg, bg = c.cobalt_dark })
hl("Pmenu", { fg = c.fg, bg = c.bg_alt })
hl("PmenuSel", { fg = c.bg, bg = c.cobalt_dark })
hl("PmenuKind", { link = "Pmenu" })
hl("PmenuKindSel", { link = "PmenuSel" })
hl("PmenuExtra", { link = "Pmenu" })
hl("PmenuExtraSel", { link = "PmenuSel" })
hl("PmenuSbar", { bg = c.bg_alt })
hl("PmenuThumb", { bg = c.comment })
hl("PmenuMatch", { fg = c.yellow, bold = true })
hl("PmenuMatchSel", { fg = c.yellow, bg = c.cobalt_dark, bold = true })
hl("ComplMatchIns", { link = "PmenuMatchSel" })

hl("StatusLine", { fg = c.yellow_light, bg = c.olive_darker })
hl("StatusLineNC", { fg = c.comment, bg = c.bg_dark })
hl("StatusLineTerm", { link = "StatusLine" })
hl("StatusLineTermNC", { link = "StatusLineNC" })

hl("TabLine", { fg = c.white, bg = c.gray_darker })
hl("TabLineSel", { fg = c.yellow, bg = c.olive_darker })
hl("TabLineFill", { fg = c.yellow, bg = c.yellow_darkest })

hl("WinBar", { fg = c.yellow_light, bg = c.olive_darker })
hl("WinBarNC", { fg = c.yellow, bg = c.bg_dark })

-- TODO: Expand on snippet implementations via builtin vim lua module vim.snippet
hl("SnippetTabstop", { fg = c.bg, bg = c.yellow, bold = true })

hl("Conceal", {}) -- placeholder characters subbed for concealed text
hl("Directory", { fg = c.cobalt_light })
hl("Cursor", { fg = c.bg, bg = c.fg }) -- character under the cursor
hl("lCursor", { link = "Cursor" })
hl("CursorIM", { link = "Cursor" })
hl("TermCursor", { link = "Cursor" })
hl("CursorColumn", { bg = c.fg_dark })
-- TODO: Change the cursor line to something beter
hl("CursorLine", { bg = c.gray_dark })

-- UI / editor ----------------------------------------------------------------

hl("WinSeparator", { fg = c.yellow, bg = c.yellow_darkest })
hl("Folded", { fg = c.orange_dark, bg = c.yellow_lighter, italic = true })
hl("FoldColumn", { bg = c.olive_darkest })
hl("SignColumn", { bg = c.olive_darkest })
hl("LineNr", { fg = c.orange_light, bg = c.bg_alt })
hl("LineNrAbove", { link = "LineNr" })
hl("LineNrBelow", { link = "LineNr" })
hl("CursorLineNr", { fg = c.orange_lighter })
hl("CursorLineFold", { bg = c.bg })
hl("CursorLineSign", { bg = c.bg })

hl("ModeMsg", { fg = c.orange_lighter })
hl("MsgArea", { fg = c.fg, bg = c.bg })
hl("MsgSeparator", { fg = c.white, bg = c.bg })
hl("MoreMsg", { fg = c.orange_light, bg = c.bg })

hl("NonText", { fg = c.fg_alt })
hl("SpecialKey", { fg = c.fg_alt })
hl("Whitespace", { fg = c.fg_alt })

hl("Question", { fg = c.cyan })
hl("QuickFixLine", { fg = c.fg, bg = c.fg_dark })

hl("SpellBad", { undercurl = true, sp = c.red })
hl("SpellCap", { undercurl = true, sp = c.yellow })
hl("SpellLocal", { undercurl = true, sp = c.cobalt })
hl("SpellRare", { undercurl = true, sp = c.purple })

hl("Visual", { reverse = true }) -- selection
hl("VisualNOS", { link = "Visual" })

hl("Error", { fg = c.error, bold = true })
hl("ErrorMsg", { fg = c.error, bold = true })
hl("WarningMsg", { fg = c.warn, bold = true })

-- Diagnostics ----------------------------------------------------------------

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
hl("@comment.error", { fg = c.error, bg = c.white, bold = true }) -- error-type comments e.g. ERROR, FIXME, DEPRECATED
hl("@comment.warning", { fg = c.warn, bold = true }) -- warning-type comments e.g. WARNING, FIX, HACK
hl("@comment.todo", { link = "1337TagTODO" }) -- todo-type comments e.g. TODO, WIP
hl("@comment.note", { fg = c.cobalt_dark, bold = true }) -- note-type comments e.g. NOTE, INFO, XXX

hl("1337TagTODO", { fg = c.todo, bg = c.white, bold = true }) -- TODO: purple
hl("1337TagPASS", { fg = c.ok, bg = c.white, bold = true }) -- PASS: green
hl("1337TagPERF", { fg = c.perf, bg = c.white, bold = true }) -- PERF: yellow
hl("1337TagFAIL", { fg = c.error, bg = c.white, bold = true }) -- FAIL: red
hl("1337TagWARN", { fg = c.warn, bg = c.white, bold = true }) -- WARNING: rust
hl("1337TagNOTE", { fg = c.hint, bg = c.white, bold = true }) -- NOTE: cobalt
hl("1337TagTEST", { fg = c.info, bg = c.white, bold = true }) -- TEST: cyan

-- User1..7 (for your statusline mode segment) --------------------------------
hl("User1", { fg = c.black, bg = c.blue, bold = true }) -- normal
hl("User2", { fg = c.black, bg = c.orange, bold = true }) -- visual
hl("User3", { fg = c.black, bg = c.rust_lighter, bold = true }) -- select
hl("User4", { fg = c.black, bg = c.green_dark, bold = true }) -- insert
hl("User5", { fg = c.black, bg = c.purple, bold = true }) -- replace
hl("User6", { fg = c.black, bg = c.red, bold = true }) -- command
hl("User7", { fg = c.black, bg = c.yellow, bold = true }) -- terminal

-- Markup (Markdown / help / etc.) ----------------------------------
hl("@markup.strong", { bold = true }) -- md bold text
hl("@markup.italic", { italic = true }) -- md italic text
hl("@markup.strikethrough", { strikethrough = true }) -- md stricken text
hl("@markup.underline", { underline = true }) -- md underlined text

hl("@markup.heading", { link = "Title" }) -- md headings, titles (including markers)
hl("@markup.heading.1", { fg = c.red, bg = c.bg_dark, bold = true }) -- md heading 1
hl("@markup.heading.2", { fg = c.orange, bg = c.bg_dark, bold = true }) -- md heading 2
hl("@markup.heading.3", { fg = c.yellow, bg = c.bg_dark, bold = true }) -- md heading 3
hl("@markup.heading.4", { fg = c.green, bg = c.bg_dark, bold = true }) -- md heading 4
hl("@markup.heading.5", { fg = c.blue, bg = c.bg_dark, bold = true }) -- md heading 5
hl("@markup.heading.6", { fg = c.purple, bg = c.bg_dark, bold = true }) -- md heading 6

hl("@markup.raw", { fg = c.gray_light, bg = c.bg_alt }) -- md inline code strings
hl("@markup.raw.block", { fg = c.gray_light, bg = c.bg_alt }) -- md code blocks

hl("@markup.list", { fg = c.yellow }) -- md list markers
hl("@markup.list.checked", { fg = c.green }) -- md checked todo-style list markers
hl("@markup.list.unchecked", { fg = c.fg_alt }) -- md  unchecked todo-style list markers
