local M = {}

-- gutter

local git_ns = vim.api.nvim_create_namespace("1337.git")

local function git_draw(buf)
    if not vim.api.nvim_buf_is_loaded(buf) then return end

    vim.api.nvim_buf_clear_namespace(buf, git_ns, 0, -1)

    local state = require("vc").get(buf)
    if not state then return end

    local line_count = vim.api.nvim_buf_line_count(buf)

    local function mark(line, symbol, highlight)
        if line < 1 or line > line_count then return end

        vim.api.nvim_buf_set_extmark(buf, git_ns, line - 1, 0, {
            sign_text = symbol,
            sign_hl_group = highlight,
            priority = 6,
        })
    end

    for _, hunk in ipairs(state.hunks) do
        local old_count, new_start, new_count = hunk[2], hunk[3], hunk[4]
        local both = math.min(old_count, new_count)

        for i = 0, both - 1 do
            local symbol = old_count > new_count and i == both - 1 and "~_" or "~"
            mark(new_start + i, symbol, "DiffChange")
        end

        for i = both, new_count - 1 do
            mark(new_start + i, "+", "DiffAdd")
        end

        if new_count == 0 then
            mark(math.max(1, new_start), "_", "DiffDelete")
        end
    end
end

-- statusline

local function stl_escape(value)
    return value:gsub("%%", "%%%%")
end

function _G.StatuslineMode()
    local mode = require("utils").mode_info()
    return string.format("%%%d* %s %%*", mode.user, mode.label)
end

function _G.StatuslineGit()
    local dict = vim.b.git_status_dict

    if not dict or not dict.head or dict.head == "" then
        return ""
    end

    local branch = "| %#Title#" .. stl_escape(dict.head) .. "%* "
    local diff = {}

    if (dict.added or 0) > 0 then
        table.insert(diff, string.format("%%#DiffAdd#+%d%%*", dict.added))
    end

    if (dict.changed or 0) > 0 then
        table.insert(diff, string.format("%%#DiffChange#~%d%%*", dict.changed))
    end

    if (dict.removed or 0) > 0 then
        table.insert(diff, string.format("%%#DiffDelete#-%d%%*", dict.removed))
    end

    if #diff > 0 then
        branch = branch .. "| " .. table.concat(diff, " ") .. " "
    end

    return branch
end

function _G.StatuslineDiagnostics()
    local counts = vim.diagnostic.count(0)
    local severities = {
        { vim.diagnostic.severity.ERROR, "E", "DiagnosticError" },
        { vim.diagnostic.severity.WARN, "W", "DiagnosticWarn" },
        { vim.diagnostic.severity.INFO, "I", "DiagnosticInfo" },
        { vim.diagnostic.severity.HINT, "H", "DiagnosticHint" },
    }

    local parts = {}

    for _, item in ipairs(severities) do
        local count = counts[item[1]] or 0
        if count > 0 then
            table.insert(parts, string.format("%%#%s#%s:%d%%*", item[3], item[2], count))
        end
    end

    if #parts == 0 then
        return ""
    end

    return "| " .. table.concat(parts, " ") .. " "
end

function _G.StatuslineFile()
    local filename = vim.fn.expand("%:t")
    local filetype = vim.bo.filetype

    if filename == "" then filename = "[No Name]" end
    if filetype == "" then filetype = "noft" end

    return "| " .. stl_escape(filename) .. " (" .. stl_escape(filetype) .. ") "
end

function _G.StatuslineZwe()
    local client = package.loaded.zwe
    local state = client and client.state and client.state(0)
    if not state then return "" end
    local graph = state.graph_state or "idle"
    return "| " .. stl_escape("ZWE: " .. state.state .. " / " .. graph) .. " "
end

-- tabline

function _G.Tabline()
    local now = os.date("*t")
    local date = string.format(
        "%s, %s %d | %02d:%02d",
        os.date("%A"),
        os.date("%B"),
        now.day,
        now.hour,
        now.min
    )

    local clients = vim.lsp.get_clients({ bufnr = 0 })

    if #clients > 0 then
        local names = {}

        for _, client in ipairs(clients) do
            table.insert(names, client.name)
        end

        table.sort(names)
        date = date .. " | LSP: " .. table.concat(names, ", ")
    end

    local tabs = {}
    local current = vim.fn.tabpagenr()

    for i = 1, vim.fn.tabpagenr("$") do
        local buffers = vim.fn.tabpagebuflist(i)
        local bufnr = buffers[vim.fn.tabpagewinnr(i)]
        local name = bufnr and vim.api.nvim_buf_get_name(bufnr) or ""
        local filename = vim.fn.fnamemodify(name, ":t")

        if filename == "" then filename = "[No Name]" end

        local label = string.format("%d:%s", i, filename)

        if i == current then
            label = "[" .. label .. "]"
        end

        local hl = i == current and "%#TabLineSel#" or "%#TabLine#"

        table.insert(tabs, string.format(
            "%s%%%dT %s %%T",
            hl,
            i,
            stl_escape(label)
        ))
    end

    return "%#TabLineFill# " .. stl_escape(date) .. "%=" ..
        table.concat(tabs) .. "%#TabLineFill#%T"
end

-- setup

function M.setup()
    -- statusline

    vim.opt.laststatus = 3
    vim.o.statusline = table.concat({
        "%{%v:lua.StatuslineMode()%}",
        "%{%v:lua.StatuslineGit()%}",
        "%{%v:lua.StatuslineDiagnostics()%}",
        "%{%v:lua.StatuslineFile()%}",
        "%{%v:lua.StatuslineZwe()%}",
        "%=",
        "[%l / %L],%c %3p%% ",
    })

    -- tabline

    vim.o.tabline = "%!v:lua.Tabline()"

    -- winbar

    vim.o.winbar = " %f%=%{get(w:, 'remote_host', hostname())} "

    -- ui refresh

    local ui_grp = vim.api.nvim_create_augroup("1337.ui", { clear = true })

    vim.api.nvim_create_autocmd("User", {
        group = ui_grp,
        pattern = { "1337ZweUpdated", "ZweWorkspaceChanged" },
        callback = function()
            vim.cmd.redrawstatus()
            vim.cmd.redrawtabline()
        end,
    })
    vim.api.nvim_create_autocmd("User", {
        group = ui_grp,
        pattern = "1337VCUpdated",
        callback = function(args)
            git_draw(args.data.buf)
            vim.cmd.redrawstatus()
        end,
    })

    vim.api.nvim_create_autocmd({ "ModeChanged", "DiagnosticChanged" }, {
        group = ui_grp,
        callback = function()
            vim.cmd.redrawstatus()
        end,
    })

    vim.api.nvim_create_autocmd({ "BufEnter", "TabEnter", "LspAttach", "LspDetach" }, {
        group = ui_grp,
        callback = function()
            vim.schedule(function()
                vim.cmd.redrawtabline()
            end)
        end,
    })

    if vim.g.custom_ui_clock then
        vim.fn.timer_stop(vim.g.custom_ui_clock)
    end

    vim.g.custom_ui_clock = vim.fn.timer_start(30000, function()
        vim.cmd.redrawtabline()
    end, { ["repeat"] = -1 })
end

return M
