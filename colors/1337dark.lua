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

c.comment  = c.mustard_lighter -- TODO: I still feel like comments are just barely off and need to be tweaked a bit
c.const    = c.cyan
c.num      = c.orange_lighter
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

hl("Constant", { fg = c.const }) -- any constant cyan
hl("Number", { fg = c.num }) -- numbers
hl("Float", { fg = c.num }) -- floats
hl("Boolean", { fg = c.num }) -- TRUE, false, etc.
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

hl("PreProc", { fg = c.type }) -- preprocessor generics
hl("Include", { fg = c.fn }) -- #include
hl("Define", { fg = c.preproc }) -- #define
hl("Macro", { fg = c.preproc }) -- same as Define
hl("PreCondit", { fg = c.type }) -- #if, #else, #endif, etc.

hl("Type", { fg = c.type }) -- int, long, char, etc.
hl("StorageClass", { fg = c.type }) -- static, register, volatile, etc.
hl("Structure", { fg = c.type }) -- struct, union, enum, etc
hl("Typedef", { fg = c.type }) -- typedef

hl("Special", { fg = c.fn }) -- special symbols - table {} in lua
hl("SpecialChar", { fg = c.num }) -- special characters in a constant '\n'
hl("Tag", {}) -- like html/xml tags
hl("SpecialComment", { fg = c.comment }) -- special things inside comments
hl("Debug", {}) -- debug statements
hl("Delimiter", {}) -- character that needs attention

hl("Underlined", { fg = c.cyan_light, underline = true }) -- like HTML links

hl("Todo", { fg = c.todo, bg = c.white, bold = true }) -- TODO FIXME XXX

hl("DiffText", { fg = c.black, bg = c.changed })
hl("Added", { fg = c.add }) -- Added line in a diff
hl("DiffAdd", { fg = c.black, bg = c.add })
hl("Changed", { fg = c.changed }) -- Changed line in a diff
hl("DiffChange", { fg = c.changed, underline = true })
hl("Removed", { fg = c.delete }) -- Removed line in a diff
hl("DiffDelete", { fg = c.black, bg = c.delete })

-- General Syntax --------------------------------------------------------------

hl("Normal", { fg = c.fg, bg = c.bg })
hl("NormalNC", { fg = c.fg_alt, bg = c.bg_light })
hl("NormalFloat", { fg = c.fg, bg = c.bg_dark })
hl("EndOfBuffer", { fg = c.orange_light, bg = c.purple_darkest })
hl("Title", { fg = c.yellow, bg = c.bg_dark, bold = true })

hl("FloatBorder", { fg = c.cobalt, bg = c.bg_dark })
hl("FloatTitle", { link = "Title" })
hl("FloatFooter", { fg = c.orange_light, bg = c.bg_dark, italic = true })

hl("ColorColumn", { bg = c.bulba_darkest })

hl("Search", { fg = c.gray_dark, bg = c.yellow })
hl("IncSearch", { fg = c.black, bg = c.orange })
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

hl("TabLine", { fg = c.fg_light, bg = c.gray_darker })
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
hl("CursorLine", { bg = c.fg_dark })

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

-- TODO: Last left off here
hl("Visual", { bg = c.cobalt_darker }) -- selection
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

-- TODO: :help treesitter-highlight
----------------------------------------------------------------------
-- Treesitter / semantic highlights blueprint
-- Based on Neovim docs + your 1337dark palette
----------------------------------------------------------------------

-- Variables ---------------------------------------------------------
-- hl("@variable", { link = "Identifier" })
-- hl("@variable.builtin", { fg = c.red, italic = true }) -- e.g. this, self
-- hl("@variable.parameter", { fg = c.var, italic = true })
-- hl("@variable.parameter.builtin", { fg = c.red, italic = true })
-- hl("@variable.member", { fg = c.var }) -- object / struct fields

-- Constants ---------------------------------------------------------
-- hl("@constant", { link = "Constant" })
-- hl("@constant.builtin", { fg = c.const, bold = true })
-- hl("@constant.macro", { link = "Macro" })

-- Modules / namespaces ---------------------------------------------
-- hl("@module", { fg = c.type }) -- modules / namespaces
-- hl("@module.builtin", { fg = c.type, bold = true })
-- hl("@label", { link = "Label" })

-- Strings -----------------------------------------------------------
-- hl("@string", { link = "String" })
-- hl("@string.documentation", { fg = c.comment, italic = true }) -- docstrings
-- hl("@string.regexp", { fg = c.cyan_light })
-- hl("@string.escape", { fg = c.cyan_lighter, bold = true })
-- hl("@string.special", { fg = c.mustard_lighter })
-- hl("@string.special.symbol", { fg = c.mustard })
-- hl("@string.special.path", { fg = c.olive_lighter })
-- hl("@string.special.url", { fg = c.cyan, underline = true })

-- Characters / literals --------------------------------------------
-- hl("@character", { link = "Character" })
-- hl("@character.special", { fg = c.orange_lighter })

-- hl("@boolean", { link = "Boolean" })
-- hl("@number", { link = "Number" })
-- hl("@number.float", { link = "Float" })

-- Types -------------------------------------------------------------
-- hl("@type", { link = "Type" })
-- hl("@type.builtin", { fg = c.type, bold = true })
-- hl("@type.definition", { link = "Typedef" })

-- hl("@attribute", { link = "PreProc" })
-- hl("@attribute.builtin", { fg = c.preproc, italic = true })
-- hl("@property", { fg = c.var }) -- keys in key/value pairs

-- Functions / methods / constructors -------------------------------
-- hl("@function", { link = "Function" })
-- hl("@function.builtin", { fg = c.fn, bold = true })
-- hl("@function.call", { link = "Function" })
-- hl("@function.macro", { link = "Macro" })

-- hl("@function.method", { link = "Function" })
-- hl("@function.method.call", { link = "Function" })

-- hl("@constructor", { fg = c.fn, bold = true })
-- hl("@operator", { link = "Operator" })

-- Keywords ----------------------------------------------------------
-- hl("@keyword", { link = "Keyword" })
-- hl("@keyword.coroutine", { fg = c.keyword, italic = true })
-- hl("@keyword.function", { link = "Keyword" })
-- hl("@keyword.operator", { link = "Keyword" })
-- hl("@keyword.import", { link = "Include" })
-- hl("@keyword.type", { fg = c.type })
-- hl("@keyword.modifier", { fg = c.keyword, italic = true })
-- hl("@keyword.repeat", { link = "Repeat" })
-- hl("@keyword.return", { fg = c.keyword, bold = true })
-- hl("@keyword.debug", { fg = c.warn })
-- hl("@keyword.exception", { link = "Exception" })

-- hl("@keyword.conditional", { link = "Conditional" })
-- hl("@keyword.conditional.ternary", { fg = c.keyword })

-- hl("@keyword.directive", { link = "PreProc" })
-- hl("@keyword.directive.define", { link = "Define" })

-- Punctuation -------------------------------------------------------
-- hl("@punctuation.delimiter", { link = "Delimiter" }) -- ; . ,
-- hl("@punctuation.bracket", { fg = c.fg }) -- () {} []
-- hl("@punctuation.special", { fg = c.special }) -- interpolation, etc.

-- Comments ----------------------------------------------------------
-- hl("@comment", { link = "Comment" })
-- hl("@comment.documentation", { fg = c.comment, italic = true })

-- hl("@comment.error", { fg = c.error, bold = true })
-- hl("@comment.warning", { fg = c.warn, bold = true })
-- hl("@comment.todo", { link = "1337TagTODO" })
-- hl("@comment.note", { fg = c.cobalt_dark, bold = true })

-- Markup (Markdown / help / etc.) ----------------------------------
-- hl("@markup.strong", { bold = true })
-- hl("@markup.italic", { italic = true })
-- hl("@markup.strikethrough", { strikethrough = true })
-- hl("@markup.underline", { underline = true })

-- hl("@markup.heading", { link = "Title" })
-- hl("@markup.heading.1", { fg = c.yellow, bold = true })
-- hl("@markup.heading.2", { fg = c.mustard_lighter, bold = true })
-- hl("@markup.heading.3", { fg = c.orange_lighter, bold = true })
-- hl("@markup.heading.4", { fg = c.cyan_light, bold = true })
-- hl("@markup.heading.5", { fg = c.cobalt_light, bold = true })
-- hl("@markup.heading.6", { fg = c.purple_lighter, bold = true })

-- hl("@markup.quote", { fg = c.comment, italic = true })
-- hl("@markup.math", { fg = c.cyan_light })

-- hl("@markup.link", { fg = c.cyan })
-- hl("@markup.link.label", { fg = c.cyan_light, underline = true })
-- hl("@markup.link.url", { fg = c.cyan, underline = true })

-- hl("@markup.raw", { fg = c.mustard_lighter }) -- inline code
-- hl("@markup.raw.block", { fg = c.mustard_lighter, bg = c.bg_dark })

-- hl("@markup.list", { fg = c.yellow })
-- hl("@markup.list.checked", { fg = c.green })
-- hl("@markup.list.unchecked", { fg = c.fg_alt })

-- Diff --------------------------------------------------------------
-- hl("@diff.plus", { link = "DiffAdd" })
-- hl("@diff.minus", { link = "DiffDelete" })
-- hl("@diff.delta", { link = "DiffChange" })

-- Tags (HTML / XML etc.) -------------------------------------------
-- hl("@tag", { fg = c.cobalt_light })
-- hl("@tag.builtin", { fg = c.cobalt_lighter, bold = true })
-- hl("@tag.attribute", { fg = c.mustard_lighter })
-- hl("@tag.delimiter", { fg = c.fg_alt })

-- TODO: :help lsp-semantic-highlight
----------------------------------------------------------------------
-- LSP semantic token highlights (vim.lsp.semantic_tokens)
-- See :h lsp-semantic-highlight
----------------------------------------------------------------------

-- TYPES / SYMBOL KINDS ----------------------------------------------

-- hl("@lsp.type.class", { link = "Type" }) -- class Foo {}
-- hl("@lsp.type.interface", { fg = c.type, italic = true }) -- interface-like types
-- hl("@lsp.type.struct", { link = "Structure" }) -- struct Foo

-- hl("@lsp.type.enum", { link = "Structure" }) -- enum Foo
-- hl("@lsp.type.enumMember", { link = "Constant" }) -- Foo::Bar

-- hl("@lsp.type.type", { link = "Type" }) -- general type
-- hl("@lsp.type.typeParameter", { fg = c.type, italic = true }) -- template <T>, generics

-- hl("@lsp.type.namespace", { fg = c.type }) -- namespaces / modules / packages

-- hl("@lsp.type.macro", { link = "Macro" }) -- MACRO_NAME
-- hl("@lsp.type.keyword", { link = "Keyword" }) -- language keywords

-- hl("@lsp.type.number", { link = "Number" }) -- numeric literal
-- hl("@lsp.type.string", { link = "String" }) -- string literal
-- hl("@lsp.type.regexp", { fg = c.cyan_light }) -- regex literal

-- hl("@lsp.type.operator", { link = "Operator" }) -- +, -, &&, etc.

-- hl("@lsp.type.function", { link = "Function" }) -- free functions
-- hl("@lsp.type.method", { link = "Function" }) -- member functions / methods

-- hl("@lsp.type.property", { fg = c.var }) -- object fields / properties
-- hl("@lsp.type.event", { fg = c.var, italic = true }) -- event-like properties

-- hl("@lsp.type.parameter", { fg = c.var, italic = true }) -- function params

-- hl("@lsp.type.variable", { link = "Identifier" }) -- local/global variables

-- hl("@lsp.type.comment", { link = "Comment" }) -- comment tokens
-- hl("@lsp.type.decorator", { link = "PreProc" }) -- decorators / annotations

-- @lsp.type.modifier       Tokens that represent a modifier

----------------------------------------------------------------------
-- MODIFIERS (applied on top of base types)
-- Keep these mostly stylistic so they compose well with the base group.
----------------------------------------------------------------------

-- hl("@lsp.mod.abstract", { italic = true }) -- abstract classes/methods
-- hl("@lsp.mod.async", { italic = true }) -- async functions

-- hl("@lsp.mod.declaration", { underline = true }) -- declarations
-- hl("@lsp.mod.definition", { bold = true }) -- definitions

-- hl("@lsp.mod.defaultLibrary", { bold = true }) -- stdlib / builtins

-- hl("@lsp.mod.deprecated", { strikethrough = true }) -- deprecated symbols
-- hl("@lsp.mod.documentation", { italic = true }) -- in docs only

-- hl("@lsp.mod.modification", { bold = true }) -- write access
-- hl("@lsp.mod.readonly", { underline = true }) -- const / readonly
-- hl("@lsp.mod.static", { underline = true, italic = true }) -- static members

-- TODO: :help lsp-highlight
----------------------------------------------------------------------
-- LSP reference / inlay / codelens / signature highlights
-- See :h lsp-highlight
----------------------------------------------------------------------

-- Reference highlights (vim.lsp.buf.document_highlight) -------------

-- Generic "text" reference (read or write)
-- hl("LspReferenceText", { fg = c.fg, bg = c.cobalt_darker, underline = true, })

-- Read references (e.g. usages)
-- hl("LspReferenceRead", { fg = c.fg, bg = c.cobalt_dark, underline = true, })

-- Write references (assignments / mutations)
-- hl("LspReferenceWrite", { fg = c.black, bg = c.orange, bold = true, })

-- Reference target (e.g. hover range / definition target)
-- hl("LspReferenceTarget", { fg = c.black, bg = c.yellow, bold = true, })

-- Inlay hints ------------------------------------------------------
-- (parameter types, inferred types, etc.)
-- hl("LspInlayHint", { fg = c.fg_alt, bg = c.bg_dark, italic = true, })

----------------------------------------------------------------------
-- LSP CodeLens
-- Used for inline virtual text above functions, tests, etc.
----------------------------------------------------------------------

-- hl("LspCodeLens", { fg = c.comment, bg = c.none, italic = true, })
-- hl("LspCodeLensSeparator", { fg = c.fg_alt, bg = c.none, })

----------------------------------------------------------------------
-- LSP Signature Help
-- vim.lsp.handlers.signature_help()
----------------------------------------------------------------------

-- hl("LspSignatureActiveParameter", { fg = c.yellow, bg = c.cobalt_darker, bold = true, })
