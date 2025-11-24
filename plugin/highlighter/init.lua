if vim.g.loaded_1337_word_highlights then
    return
end
vim.g.loaded_1337_word_highlights = true

local api = vim.api
local ns = api.nvim_create_namespace("1337.comment_tags")

local TAGS = {
    {
        hl = "1337TagTODO",
        words = {
            " TODO:", -- TODO: Leave a comment for something you need to get done.
            " LLO:", -- LLO: last left off.
            " START:", -- START: starts/go here first
            " END:", -- END: ends/go here last
            " HERE:", -- HERE: go here
        },
    },
    {
        hl = "1337TagTEST",
        words = {
            " TEST:", -- TEST: testing or test
            " EXP:", -- EXP: experimental block
            " TEMP:", -- TEMP: this is temporary
        },
    },
    {
        hl = "1337TagPASS",
        words = {
            " PASS:", -- PASS: passing test
        },
    },
    {
        hl = "1337TagPERF",
        words = {
            " PERF:", -- PERF: performance block
            " OPTIM:", -- OPTIM: optimized/optimal/ or optimization block
        },
    },
    {
        hl = "1337TagFAIL",
        words = {
            " FAIL:", -- FAIL: Failed block
            " ERROR:", -- ERROR: This probably breaks things
            " FIXME:", -- FIXME: please?
            " BUG:", -- BUG: Eww, squish it!
        },
    },
    {
        hl = "1337TagWARN",
        words = {
            " WARNING:", -- WARNING: You have been warned...
            " HACK:", -- HACK: This was hacked up!
            " CAUTION:", -- CAUTION: Proceed with caution, ok?
        },
    },
    {
        hl = "1337TagNOTE",
        words = {
            " NOTE:", -- NOTE: Small note info.
            " INFO:", -- INFO: General info.
            " NEW:", -- NEW: New info.
            " OLD:", -- OLD: old info.
        },
    },
}

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

-- Is (row,col) inside a comment? Prefer Tree-sitter; fall back to :syntax.
local function in_comment(bufnr, row, col)
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

    local id  = vim.fn.synID(row + 1, col + 1, 1)
    local tid = vim.fn.synIDtrans(id)
    local nm  = vim.fn.synIDattr(tid, "name")
    return type(nm) == "string" and nm:lower():find("comment", 1, true) ~= nil
end

-- Hex color highlighter: "#RRGGBB" -> colored bg, easy-to-read fg.
local function highlight_hex_colors(bufnr, row, line)
    local init = 1

    while true do
        -- find 6-digit hex like #ff00aa / #FF00AA
        local s, e = line:find("#%x%x%x%x%x%x", init)
        if not s then break end

        local col0      = s - 1
        local color     = line:sub(s, e) -- "#rrggbb"
        local group     = "1337Hex_" .. color:sub(2) -- "1337Hex_ff00aa"

        -- compute a readable foreground based on brightness of bg
        local r         = tonumber(color:sub(2, 3), 16) or 0
        local g         = tonumber(color:sub(4, 5), 16) or 0
        local b         = tonumber(color:sub(6, 7), 16) or 0

        -- standard luma-ish formula
        local luminance = 0.299 * r + 0.587 * g + 0.114 * b
        local fg        = (luminance > 186) and "#000000" or "#ffffff"

        -- bg is the hex, fg is auto-picked for contrast
        api.nvim_set_hl(0, group, { bg = color, fg = fg })
        api.nvim_buf_add_highlight(bufnr, ns, group, row, col0, col0 + #color)

        init = e + 1
    end
end

-- Range-based scan & highlight (clears + repaints only the range)
local function refresh_range(bufnr, srow, erow)
    bufnr = bufnr or 0
    if not api.nvim_buf_is_loaded(bufnr) then return end

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
                    if not s then break end
                    local col0 = s - 1
                    if in_comment(bufnr, row, col0) then
                        api.nvim_buf_add_highlight(
                            bufnr, ns, tag.hl, row, col0, col0 + #word
                        )
                    end
                    init = e + 1
                end
            end
        end

        -- Hex color highlighting (#000000 -> #ffffff)
        highlight_hex_colors(bufnr, row, line)
    end
end

local function refresh(bufnr)
    refresh_range(bufnr or 0, 0, -1)
end

--------------------------------------------------------------------------------
-- Tree-sitter incremental updates
--------------------------------------------------------------------------------

local UINT_MAX = 0xFFFFFFFF

local function handle_ts_changes(bufnr, changes)
    local minr, maxr = math.huge, -1
    local lastrow    = math.max(0, api.nvim_buf_line_count(bufnr) - 1)

    for _, ch in ipairs(changes or {}) do
        local sr, er
        if type(ch[1]) == "table" and type(ch[2]) == "table" then
            -- { {sr,sc,sb}, {er,ec,eb} }
            sr = ch[1][1] or 0
            er = ch[2][1] or sr
        else
            -- { sr, sc, [sb], er, ec, [eb] }
            sr = ch[1] or 0
            er = ch[4] or ch[3] or sr
            -- Full-buffer sentinel -> normalize to whole buffer
            if type(er) == "number" and er >= UINT_MAX / 2 then
                sr, er = 0, lastrow
            end
        end
        sr = math.max(0, math.min(sr, lastrow))
        er = math.max(sr, math.min(er, lastrow))
        if sr < minr then minr = sr end
        if er > maxr then maxr = er end
    end

    if minr == math.huge then
        refresh_range(bufnr, 0, -1)
    else
        refresh_range(bufnr, minr, maxr)
    end
end

local function attach_ts(bufnr)
    -- Start TS highlighter so on_changedtree fires during edits
    pcall(vim.treesitter.start, bufnr)
    -- Initial paint
    refresh_range(bufnr, 0, -1)

    local ok, parser = pcall(vim.treesitter.get_parser, bufnr)
    if not ok or not parser then return end

    parser:register_cbs({
        on_changedtree = function(changes, _)
            vim.schedule(function()
                if api.nvim_buf_is_valid(bufnr) then
                    handle_ts_changes(bufnr, changes)
                end
            end)
        end,
    })
end

--------------------------------------------------------------------------------
-- Autocommands + user command
--------------------------------------------------------------------------------

-- Manual refresh command
api.nvim_create_user_command("CommentTagsRefresh", function()
    refresh(0)
end, { desc = "Refresh comment tag & hex highlights (token-only)" })

-- Tree-sitter-based incremental updates
local grp_ts = api.nvim_create_augroup("1337CommentTagsTS", { clear = true })
api.nvim_create_autocmd({ "BufEnter", "FileType" }, {
    group = grp_ts,
    pattern = "*",
    desc = "Attach TreeSitter-based comment tags if parser is available",
    callback = function(args)
        if vim.b[args.buf].comment_tags_ts_attached then return end
        local ok = pcall(vim.treesitter.get_parser, args.buf)
        if not ok then return end
        vim.b[args.buf].comment_tags_ts_attached = true
        attach_ts(args.buf)
    end,
})

-- Fallback when TS is not attached
local grp_fb = api.nvim_create_augroup("1337CommentTagsFallback", { clear = true })
api.nvim_create_autocmd({ "BufEnter", "TextChanged", "InsertLeave", "BufWritePost" }, {
    group = grp_fb,
    pattern = "*",
    desc = "Fallback refresh of comment tags when TreeSitter is not attached",
    callback = function(args)
        if vim.b[args.buf].comment_tags_ts_attached then return end -- TS will handle it
        refresh(args.buf)
    end,
})

-- Reapply groups & repaint on colorscheme reload
api.nvim_create_autocmd("ColorScheme", {
    group = grp_fb,
    pattern = "*",
    desc = "Reapply comment tags on colorscheme reload",
    callback = function()
        if api.nvim_buf_is_valid(0) then
            refresh(0)
        end
    end,
})

-- Initial apply for current buffer (if any)
pcall(refresh, 0)
