local M = {}

-- highlighter utilities

local hi_util = {}
local hi_refresh_events = { "BufEnter", "BufWritePost", "TextChanged", "TextChangedI" }

function hi_util.fg_for(bg)
    local r = tonumber(bg:sub(2, 3), 16) or 0
    local g = tonumber(bg:sub(4, 5), 16) or 0
    local b = tonumber(bg:sub(6, 7), 16) or 0
    local luminance = 0.299 * r + 0.587 * g + 0.114 * b
    return (luminance > 186) and "#000000" or "#ffffff"
end

function hi_util.parse_treesitter(bufnr)
    if not vim.treesitter or not vim.treesitter.get_parser then
        return
    end

    pcall(function()
        local parser = vim.treesitter.get_parser(bufnr)
        parser:parse({ 0, vim.api.nvim_buf_line_count(bufnr) })
    end)
end

function hi_util.in_capture(bufnr, row, col, needle)
    if vim.treesitter and vim.treesitter.get_captures_at_pos then
        local ok, caps = pcall(vim.treesitter.get_captures_at_pos, bufnr, row, col)
        if ok and caps then
            for _, cap in ipairs(caps) do
                local name = (type(cap) == "table") and cap.capture or cap
                if type(name) == "string" and name:lower():find(needle, 1, true) then
                    return true
                end
            end
        end
    end

    local id = vim.fn.synID(row + 1, col + 1, 1)
    local tid = vim.fn.synIDtrans(id)
    local name = vim.fn.synIDattr(tid, "name")
    return type(name) == "string" and name:lower():find(needle, 1, true) ~= nil
end

function hi_util.in_comment(bufnr, row, col)
    return hi_util.in_capture(bufnr, row, col, "comment")
end

function hi_util.in_string(bufnr, row, col)
    return hi_util.in_capture(bufnr, row, col, "string")
end

-- tag highlighter

local tag_hi_ns = vim.api.nvim_create_namespace("1337.tag_highlighter")

local hi_tags = {
    { hl = "1337TagTODO", words = { "TODO:", "LLO:", "START:", "END:", "HERE:" } },
    { hl = "1337TagTEST", words = { "TEST:", "EXP:", "TEMP:" } },
    { hl = "1337TagPASS", words = { "PASS:" } },
    { hl = "1337TagPERF", words = { "PERF:", "OPTIM:" } },
    { hl = "1337TagFAIL", words = { "FAIL:", "ERROR:", "FIXME:", "BUG:" } },
    { hl = "1337TagWARN", words = { "WARNING:", "HACK:", "CAUTION:" } },
    { hl = "1337TagNOTE", words = { "NOTE:", "INFO:", "NEW:", "OLD:" } },
}

local function refresh_tag_highlights(bufnr, lines)
    local api = vim.api

    api.nvim_buf_clear_namespace(bufnr, tag_hi_ns, 0, -1)

    for i, line in ipairs(lines) do
        local row = i - 1

        for _, tag in ipairs(hi_tags) do
            for _, word in ipairs(tag.words) do
                local init = 1
                while true do
                    local s, e = line:find(word, init, true)
                    if not s then
                        break
                    end

                    local col0 = s - 1
                    if hi_util.in_comment(bufnr, row, col0) then
                        api.nvim_buf_set_extmark(bufnr, tag_hi_ns, row, col0, {
                            end_col = col0 + #word,
                            hl_group = tag.hl,
                            priority = 210,
                        })
                    end

                    init = e + 1
                end
            end
        end
    end
end

-- hex highlighter

local hex_hi_ns = vim.api.nvim_create_namespace("1337.hex_highlighter")
local hex_hi_groups = {}

local function hex_hi_group(hex)
    local name = hex_hi_groups[hex]
    if name then
        return name
    end

    name = "1337Hex_" .. hex:sub(2):upper()
    vim.api.nvim_set_hl(0, name, {
        fg = hi_util.fg_for(hex),
        bg = hex,
        force = true,
    })
    hex_hi_groups[hex] = name
    return name
end

local function refresh_hex_highlights(bufnr, lines)
    local api = vim.api

    api.nvim_buf_clear_namespace(bufnr, hex_hi_ns, 0, -1)

    for i, line in ipairs(lines) do
        local row = i - 1
        local init = 1

        while true do
            local s, e = line:find("#%x%x%x%x%x%x", init)
            if not s then
                break
            end

            local col0 = s - 1
            local hex = line:sub(s, e)

            if hi_util.in_string(bufnr, row, col0) then
                api.nvim_buf_set_extmark(bufnr, hex_hi_ns, row, col0, {
                    end_col = col0 + #hex,
                    hl_group = hex_hi_group(hex),
                    priority = 210,
                })
            end

            init = e + 1
        end
    end
end

-- One scheduled task for both decorations; byte synchronization is not throttled here.
local pending, last_tick = {}, {}
local epoch = 0
local function schedule(buf, force)
    if not buf or buf == 0 then buf = vim.api.nvim_get_current_buf() end
    if force then last_tick[buf] = nil end
    if pending[buf] then return end
    local generation = epoch
    pending[buf] = true
    vim.schedule(function()
        if generation ~= epoch then return end
        pending[buf] = nil
        if not vim.api.nvim_buf_is_loaded(buf) or vim.bo[buf].buftype ~= "" then return end
        local tick = vim.api.nvim_buf_get_changedtick(buf)
        if last_tick[buf] == tick then return end
        vim.api.nvim_buf_call(buf, function()
            hi_util.parse_treesitter(buf)
            local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
            refresh_tag_highlights(buf, lines)
            refresh_hex_highlights(buf, lines)
        end)
        last_tick[buf] = tick
    end)
end
function M.setup(opts)
    opts = opts or {}
    epoch = epoch + 1
    pending, last_tick = {}, {}
    -- Remove previous groups when re-sourcing this module.
    for _, group in ipairs({ "1337.tag_highlighter", "1337.hex_highlighter" }) do
        pcall(vim.api.nvim_del_augroup_by_name, group)
    end
    local group = vim.api.nvim_create_augroup("1337.syntax", { clear = true })
    vim.api.nvim_create_autocmd("FileType", { group = group, callback = function(e)
        if opts.cst == "treesitter" then pcall(vim.treesitter.start, e.buf) end
        schedule(e.buf, true)
    end })
    vim.api.nvim_create_autocmd(hi_refresh_events, { group = group, callback = function(e) schedule(e.buf) end })
    vim.api.nvim_create_autocmd("BufWipeout", { group = group, callback = function(e)
        pending[e.buf], last_tick[e.buf] = nil, nil
    end })
    vim.api.nvim_create_autocmd("ColorScheme", { group = group, callback = function()
        local previous = hex_hi_groups
        hex_hi_groups = {}
        for hex in pairs(previous) do hex_hi_group(hex) end
        for _, buf in ipairs(vim.api.nvim_list_bufs()) do schedule(buf, true) end
    end })
    schedule(0, true)
end
return M
