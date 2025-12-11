if vim.g.loaded_1337_word_highlights then
    return
end
vim.g.loaded_1337_word_highlights = true

local api                         = vim.api
local ns                          = api.nvim_create_namespace("1337.comment_tags")

----------------------------------------------------------------------
-- PALETTE (only the parts you care about here)
----------------------------------------------------------------------

local c                           = {
    none          = "none",

    black         = "#000000",
    white         = "#ffffff",

    gray          = "#5c5c5c",
    gray_light    = "#a0a0a0",
    gray_lighter  = "#d0d0d0",

    red_lighter   = "#ff7772",
    red           = "#f63b34",

    orange        = "#ff8800",

    yellow_darker = "#ffd76d",

    green         = "#6fae47",

    cyan          = "#46b6c2",
    cyan_dark     = "#3f8f9b",

    cobalt_dark   = "#38728a",
    cobalt_light  = "#61afdf",

    blue          = "#3b6bb5",
    purple        = "#a761c4",
}

-- semantic aliases (same as your scheme)
c.fg                              = c.gray_lighter
c.fg_dark                         = c.gray
c.fg_alt                          = c.gray_light

c.error                           = c.red
c.warn                            = c.orange
c.info                            = c.cyan_dark -- used also for test
c.hint                            = c.cobalt_dark
c.ok                              = c.green
c.perf                            = c.yellow_darker
c.todo                            = c.purple
c.test                            = c.blue

----------------------------------------------------------------------
-- HL helper + tag highlight groups
----------------------------------------------------------------------

local function hl(name, val)
    val.force = true
    val.cterm = val.cterm or {}
    api.nvim_set_hl(0, name, val)
end

hl("1337TagTODO", { fg = c.todo, bg = c.white, bold = true }) -- TODO: purple-ish
hl("1337TagPASS", { fg = c.ok, bg = c.white, bold = true }) -- PASS: green
hl("1337TagPERF", { fg = c.perf, bg = c.white, bold = true }) -- PERF: yellow
hl("1337TagFAIL", { fg = c.error, bg = c.white, bold = true }) -- FAIL: red
hl("1337TagWARN", { fg = c.warn, bg = c.white, bold = true }) -- WARNING: rust/orange
hl("1337TagNOTE", { fg = c.hint, bg = c.white, bold = true }) -- NOTE: cobalt
hl("1337TagTEST", { fg = c.info, bg = c.white, bold = true }) -- TEST: cyan

----------------------------------------------------------------------
-- TAG DEFINITIONS (same as your original)
----------------------------------------------------------------------

local TAGS = {
    {
        hl = "1337TagTODO",
        icon = " ",
        words = { " TODO:", " LLO:", " START:", " END:", " HERE:" },
    },
    {
        hl = "1337TagTEST",
        icon = " ",
        words = { " TEST:", " EXP:", " TEMP:" },
    },
    {
        hl = "1337TagPASS",
        icon = " ",
        words = { " PASS:" },
    },
    {
        hl = "1337TagPERF",
        icon = "󱐋 ",
        words = { " PERF:", " OPTIM:" },
    },
    {
        hl = "1337TagFAIL",
        icon = " ",
        words = { " FAIL:", " ERROR:", " FIXME:", " BUG:" },
    },
    {
        hl = "1337TagWARN",
        icon = " ",
        words = { " WARNING:", " HACK:", " CAUTION:" },
    },
    {
        hl = "1337TagNOTE",
        icon = " ",
        words = { " NOTE:", " INFO:", " NEW:", " OLD:" },
    },
}

----------------------------------------------------------------------
-- SIGN DEFINITIONS (gutter icons)
----------------------------------------------------------------------

local function define_signs()
    for _, tag in ipairs(TAGS) do
        local sign_name = tag.hl .. "Sign"

        -- tag.icon must exist; you can default it if needed:
        local icon = tag.icon or "●"

        vim.fn.sign_define(sign_name, {
            text = icon,
            texthl = tag.hl,
            numhl = "",
        })

        tag.sign_name = sign_name -- store for later
    end
end

define_signs()


-- Is (row,col) inside a comment? Prefer Tree-sitter; fall back to syntax.
local function in_comment(bufnr, row, col)
    -- Tree-sitter based check
    if vim.treesitter and vim.treesitter.get_captures_at_pos then
        local ok, caps = pcall(vim.treesitter.get_captures_at_pos, bufnr, row, col)
        if ok and caps then
            for _, cap in ipairs(caps) do
                local name = (type(cap) == "table") and cap.capture or cap
                if type(name) == "string" and name:lower():find("comment", 1, true) then
                    return true
                end
            end
        end
    end

    -- Syntax-based fallback
    local id  = vim.fn.synID(row + 1, col + 1, 1)
    local tid = vim.fn.synIDtrans(id)
    local nm  = vim.fn.synIDattr(tid, "name")
    return type(nm) == "string" and nm:lower():find("comment", 1, true) ~= nil
end

-- Hex color highlighter: "#RRGGBB" -> colored bg, readable fg.
local function highlight_hex_colors(bufnr, row, line)
    local init = 1

    while true do
        local s, e = line:find("#%x%x%x%x%x%x", init)
        if not s then
            break
        end

        local col0      = s - 1
        local color     = line:sub(s, e) -- "#rrggbb"
        local group     = "1337Hex_" .. color:sub(2)

        -- compute contrast fg
        local r         = tonumber(color:sub(2, 3), 16) or 0
        local g         = tonumber(color:sub(4, 5), 16) or 0
        local b         = tonumber(color:sub(6, 7), 16) or 0

        local luminance = 0.299 * r + 0.587 * g + 0.114 * b
        local fg        = (luminance > 186) and "#000000" or "#ffffff"

        api.nvim_set_hl(0, group, { bg = color, fg = fg })
        api.nvim_buf_add_highlight(bufnr, ns, group, row, col0, col0 + #color)

        init = e + 1
    end
end

-- Tag + hex highlighting on a line range
local function highlight_range(bufnr, srow, erow)
    bufnr = bufnr or 0
    if not api.nvim_buf_is_loaded(bufnr) then
        return
    end

    -- Clear all signs in this range
    for l = srow, erow do
        vim.fn.sign_unplace("1337CommentTagSigns", { buffer = bufnr, id = l + 1 })
    end

    local last = math.max(0, api.nvim_buf_line_count(bufnr) - 1)
    srow = math.max(0, tonumber(srow) or 0)
    erow = (erow == nil or erow < 0) and last
        or math.min(tonumber(erow) or last, last)

    api.nvim_buf_clear_namespace(bufnr, ns, srow, erow + 1)
    local lines = api.nvim_buf_get_lines(bufnr, srow, erow + 1, false)

    for i, line in ipairs(lines) do
        local row = srow + i - 1

        -- Comment tag highlighting
        for _, tag in ipairs(TAGS) do
            for _, word in ipairs(tag.words) do
                local init = 1
                while true do
                    local s, e = line:find(word, init, true) -- plain search
                    if not s then
                        break
                    end
                    local col0 = s - 1
                    if in_comment(bufnr, row, col0) then
                        api.nvim_buf_add_highlight(bufnr, ns, tag.hl, row, col0, col0 + #word)

                        -- place gutter icon
                        vim.fn.sign_place(
                            row + 1, -- ID tied to the line
                            "1337CommentTagSigns", -- sign group
                            tag.sign_name, -- pre-defined sign
                            bufnr,
                            { lnum = row + 1, priority = 80 }
                        )
                    end
                    init = e + 1
                end
            end
        end

        -- Hex color highlighting anywhere in the line
        highlight_hex_colors(bufnr, row, line)
    end
end

local function refresh(bufnr)
    highlight_range(bufnr or 0, 0, -1)
end

----------------------------------------------------------------------
-- Autocommands
----------------------------------------------------------------------

local grp = api.nvim_create_augroup("1337CommentTagsSimple", { clear = true })

api.nvim_create_autocmd({ "BufEnter", "BufWritePost", "TextChanged", "TextChangedI" }, {
    group = grp,
    pattern = "*",
    desc = "Highlight 1337 comment tags & hex colors",
    callback = function(args)
        refresh(args.buf)
    end,
})

api.nvim_create_autocmd("ColorScheme", {
    group = grp,
    pattern = "*",
    desc = "Reapply 1337 comment tags & hex colors on colorscheme change",
    callback = function()
        refresh(0)
    end,
})

-- Initial pass on current buffer
pcall(refresh, 0)
