-- utils

P = function(v)
    print(vim.inspect(v))
    return v
end

local mode_labels = {
    n = "[N]",
    no = "[NP]",
    nov = "[NP-V]",
    noV = "[NP-VL]",
    ["no\22"] = "[NP-VB]",
    nt = "[NT]",
    niI = "[N->I]",
    niR = "[N->R]",
    niV = "[N->Rv]",
    ntT = "[NT->T]",
    v = "[V]",
    vs = "[V-S]",
    V = "[VL]",
    Vs = "[VL-S]",
    ["\22"] = "[VB]",
    ["\22s"] = "[VB-S]",
    s = "[S]",
    S = "[SL]",
    ["\19"] = "[SB]",
    i = "[I]",
    ic = "[I-c]",
    ix = "[I-cx]",
    R = "[R]",
    Rc = "[R-c]",
    Rx = "[R-cx]",
    Rv = "[Rv]",
    Rvc = "[Rv-c]",
    Rvx = "[Rv-cx]",
    c = "[C]",
    cr = "[C-r]",
    cv = "[Ex]",
    cvr = "[Ex-r]",
    t = "[T]",
    r = "[Hit]",
    rm = "[More]",
    ["r?"] = "[Conf]",
    ["!"] = "[!]",
}

local function mode_info(raw)
    raw = raw or vim.fn.mode(1)
    local first = raw:sub(1, 1)
    local map, user = "n", 1

    if raw:sub(1, 2) == "no" then
        map = "o"
    elseif first == "v" or first == "V" or first == "\22" then
        map, user = "x", 2
    elseif first == "s" or first == "S" or first == "\19" then
        map, user = "s", 3
    elseif first == "i" then
        map, user = "i", 4
    elseif first == "R" then
        map, user = "i", 5
    elseif first == "c" then
        map, user = "c", 6
    elseif first == "t" then
        map, user = "t", 7
    end

    return {
        raw = raw,
        map = map,
        label = mode_labels[raw] or "[?]",
        user = user,
    }
end

-- colorscheme, from colors/ dir

vim.cmd.colorscheme("1337dark")

-- settings

vim.g.mapleader = " "
vim.g.maplocalleader = " "
vim.g.have_nerd_font = true

vim.schedule(function() vim.opt.clipboard = "unnamedplus" end)

vim.opt.number = true
vim.opt.relativenumber = true

vim.opt.foldlevel = 99

vim.opt.cursorline = true
vim.opt.colorcolumn = "80"

vim.opt.expandtab = true
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.smartindent = true

vim.opt.list = true
vim.opt.listchars = { tab = "<->", trail = ".", nbsp = "-" }

vim.opt.showmode = false
vim.opt.showtabline = 2

vim.opt.splitright = true
vim.opt.splitbelow = true

vim.opt.winblend = 10

vim.opt.wrap = false
vim.opt.linebreak = true
vim.opt.scrolloff = 1
vim.opt.sidescrolloff = 1

vim.opt.undofile = true
vim.opt.swapfile = false

vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.inccommand = "split"
vim.opt.iskeyword:append("-")

vim.opt.updatetime = 300
vim.opt.timeoutlen = 300

vim.opt.autocomplete = true
vim.opt.completeopt = "menuone,noinsert,noselect"
vim.opt.pumheight = 10
vim.opt.pumblend = 15

local format_opts_remove_cro = vim.api.nvim_create_augroup("1337.format_opts_remove_cro", { clear = true })
vim.api.nvim_create_autocmd("BufEnter", {
    group = format_opts_remove_cro,
    pattern = "*",
    callback = function()
        vim.opt.formatoptions:remove({ "c", "r", "o" })
    end,
    desc = "1337: Removes automatic continuation comments",
})

local wrap_spell_on_ft = vim.api.nvim_create_augroup("1337.wrap_spell_on_ft", { clear = true })
vim.api.nvim_create_autocmd("FileType", {
    group = wrap_spell_on_ft,
    pattern = "*",
    callback = function()
        local ft = vim.bo.filetype
        if ft == "markdown" or ft == "norg" or ft == "text" then
            vim.opt_local.wrap = true
            vim.opt_local.spell = true
        end
    end,
    desc = "1337: Enables wrap+spell for prose-like filetypes",
})

-- keymaps

vim.keymap.set("x", "<leader>p", [["_dP]], { silent = true, desc = "1337: paste over without yanking" })
vim.keymap.set({ "n", "v" }, "<leader>d", [["_d]], { silent = true, desc = "1337: delete without yanking" })
vim.keymap.set("n", "<leader><C-l>", "<cmd>nohlsearch<cr>", { silent = true, desc = "1337: Clears search highlights" })
vim.keymap.set("n", "J", "mzJ`z", { silent = true, desc = "1337: Join lines, keep cursor position" })

-- Explorer TODO: Replace netrw with Neovim's native directory explorer in 0.13.x.

vim.cmd.packadd("netrw")
vim.keymap.set("n", "<leader>e", "<cmd>Explore<CR>", { silent = true, desc = "Explorer" })

-- autocommands

local mkview_on_leave = vim.api.nvim_create_augroup("1337.mkview_on_leave", { clear = true })
vim.api.nvim_create_autocmd("BufWinLeave", {
    group = mkview_on_leave,
    pattern = "*.*",
    command = "mkview",
    desc = "1337: mkview on window leave",
})

local loadview_on_enter = vim.api.nvim_create_augroup("1337.loadview_on_enter", { clear = true })
vim.api.nvim_create_autocmd("BufWinEnter", {
    group = loadview_on_enter,
    pattern = "*.*",
    command = "silent! loadview",
    desc = "1337: loadview on window enter",
})

local hl_on_yank = vim.api.nvim_create_augroup("1337.hl_on_yank", { clear = true })
vim.api.nvim_create_autocmd("TextYankPost", {
    group = hl_on_yank,
    pattern = "*",
    callback = function()
        vim.hl.on_yank({ higroup = "IncSearch", timeout = 40 })
    end,
    desc = "1337: Brief highlight on yank",
})

-- diagnostics

vim.diagnostic.config({
    severity_sort = true,
    float = { border = "rounded", source = "if_many" },
    underline = { severity = vim.diagnostic.severity.ERROR },
    signs = vim.g.have_nerd_font and {
        text = {
            [vim.diagnostic.severity.ERROR] = "󰅚 ",
            [vim.diagnostic.severity.WARN] = "󰀪 ",
            [vim.diagnostic.severity.INFO] = "󰋽 ",
            [vim.diagnostic.severity.HINT] = "󰌶 ",
        },
    } or {},
    virtual_text = {
        source = "if_many",
        spacing = 2,
    },
})

-- lsp

vim.lsp.config("*", {
    capabilities = {
        textDocument = {
            semanticTokens = {
                multilineTokenSupport = true,
            },
        },
    },
    root_markers = { ".git" },
})

vim.lsp.enable({
    "clangd",
    "gopls",
    "lua_ls",
    "rust_analyzer",
    "zls",
})

local m = vim.lsp.protocol.Methods

local lsp_attach_grp = vim.api.nvim_create_augroup("LSP.attach", { clear = true })
local lsp_highlight_grp = vim.api.nvim_create_augroup("LSP.highlight", { clear = false })
local lsp_detach_grp = vim.api.nvim_create_augroup("LSP.detach", { clear = true })

vim.api.nvim_create_autocmd("LspAttach", {
    group = lsp_attach_grp,
    desc = "LSP: Buffer-local keymaps and features",
    callback = function(e)
        local bufnr = e.buf
        local client = vim.lsp.get_client_by_id(e.data.client_id)

        vim.keymap.set("n", "grd", vim.lsp.buf.definition, {
            buffer = bufnr,
            silent = true,
            desc = "LSP: goto definition",
        })
        vim.keymap.set("n", "grD", vim.lsp.buf.declaration, {
            buffer = bufnr,
            silent = true,
            desc = "LSP: goto declaration",
        })
        vim.keymap.set("n", "gW", vim.lsp.buf.workspace_symbol, {
            buffer = bufnr,
            silent = true,
            desc = "LSP: workspace symbols",
        })
        vim.keymap.set("n", "K", vim.lsp.buf.hover, {
            buffer = bufnr,
            silent = true,
            desc = "LSP: hover docs",
        })

        if client and client:supports_method(m.textDocument_inlayHint) then
            vim.keymap.set("n", "<leader>th", function()
                local on = vim.lsp.inlay_hint.is_enabled({ bufnr = bufnr })
                vim.lsp.inlay_hint.enable(not on, { bufnr = bufnr })
            end, {
                buffer = bufnr,
                silent = true,
                desc = "LSP: [t]oggle inlay [h]ints",
            })
        end

        if client and client:supports_method(m.textDocument_formatting) then
            local format_grp = vim.api.nvim_create_augroup(("LSP.format_%d"):format(bufnr), { clear = true })

            vim.api.nvim_create_autocmd("BufWritePre", {
                group = format_grp,
                buffer = bufnr,
                desc = "LSP: format on save",
                callback = function()
                    vim.lsp.buf.format({
                        bufnr = bufnr,
                        id = client.id,
                        timeout_ms = 1500,
                    })
                end,
            })
        end

        if client and client:supports_method(m.textDocument_documentHighlight) then
            vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
                group = lsp_highlight_grp,
                buffer = bufnr,
                callback = vim.lsp.buf.document_highlight,
            })

            vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
                group = lsp_highlight_grp,
                buffer = bufnr,
                callback = vim.lsp.buf.clear_references,
            })
        end
    end,
})

vim.api.nvim_create_autocmd("LspDetach", {
    group = lsp_detach_grp,
    desc = "LSP: clear references and buffer-local LSP autocmds on detach",
    callback = function(event)
        vim.lsp.buf.clear_references()
        vim.api.nvim_clear_autocmds({ group = lsp_highlight_grp, buffer = event.buf })
    end,
})

local treesitter_filetypes = {
    -- baseline
    "bash",
    "c",
    "diff",
    "html",
    "lua",
    "luadoc",
    "markdown",
    "markdown_inline",
    "query",
    "vim",
    "vimdoc",
}
local treesitter_ft_grp = vim.api.nvim_create_augroup("1337.treesitter.filetypes", { clear = true })

vim.api.nvim_create_autocmd("FileType", {
    group = treesitter_ft_grp,
    pattern = treesitter_filetypes,
    callback = function(args)
        pcall(vim.treesitter.start, args.buf)
    end,
})

-- utils_highlighter

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

function hi_util.schedule_buf(fn, bufnr)
    bufnr = (bufnr == nil or bufnr == 0) and vim.api.nvim_get_current_buf() or bufnr

    vim.schedule(function()
        if not vim.api.nvim_buf_is_loaded(bufnr) or vim.bo[bufnr].buftype ~= "" then
            return
        end

        vim.api.nvim_buf_call(bufnr, function()
            fn(bufnr)
        end)
    end)
end

-- tag_highlighter

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

local function refresh_tag_highlights(bufnr)
    local api = vim.api

    hi_util.parse_treesitter(bufnr)
    api.nvim_buf_clear_namespace(bufnr, tag_hi_ns, 0, -1)

    local lines = api.nvim_buf_get_lines(bufnr, 0, -1, false)
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

local tag_hi_grp = vim.api.nvim_create_augroup("1337.tag_highlighter", { clear = true })

vim.api.nvim_create_autocmd(hi_refresh_events, {
    group = tag_hi_grp,
    callback = function(args)
        hi_util.schedule_buf(refresh_tag_highlights, args.buf)
    end,
    desc = "1337: highlight comment tags",
})

hi_util.schedule_buf(refresh_tag_highlights, 0)

-- hex_highlighter

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

local function refresh_hex_highlights(bufnr)
    local api = vim.api

    hi_util.parse_treesitter(bufnr)
    api.nvim_buf_clear_namespace(bufnr, hex_hi_ns, 0, -1)

    local lines = api.nvim_buf_get_lines(bufnr, 0, -1, false)
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

local hex_hi_grp = vim.api.nvim_create_augroup("1337.hex_highlighter", { clear = true })

vim.api.nvim_create_autocmd(hi_refresh_events, {
    group = hex_hi_grp,
    callback = function(args)
        hi_util.schedule_buf(refresh_hex_highlights, args.buf)
    end,
    desc = "1337: highlight hex colors in strings",
})

vim.api.nvim_create_autocmd("ColorScheme", {
    group = hex_hi_grp,
    callback = function()
        local previous = hex_hi_groups
        hex_hi_groups = {}

        for hex in pairs(previous) do
            hex_hi_group(hex)
        end
    end,
    desc = "1337: reapply hex color highlights",
})

hi_util.schedule_buf(refresh_hex_highlights, 0)

-- git gutter

local git_ns = vim.api.nvim_create_namespace("1337.git")
local git_buffers = {}
local git_group = vim.api.nvim_create_augroup("1337.git", { clear = true })

local function git_draw(buf)
    if not vim.api.nvim_buf_is_loaded(buf) then return end
    local state = git_buffers[buf]
    if not state then return end

    vim.api.nvim_buf_clear_namespace(buf, git_ns, 0, -1)

    local added, changed, removed = 0, 0, 0
    if state.base and not state.base:find("\0", 1, true) then
        local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
        local text = table.concat(lines, "\n")
        if vim.bo[buf].endofline then text = text .. "\n" end

        local function mark(line, symbol, highlight)
            if line < 1 or line > #lines then return end
            vim.api.nvim_buf_set_extmark(buf, git_ns, line - 1, 0, {
                sign_text = symbol,
                sign_hl_group = highlight,
                priority = 6,
            })
        end

        for _, hunk in ipairs(vim.text.diff(state.base, text, { result_type = "indices" })) do
            local old_count, new_start, new_count = hunk[2], hunk[3], hunk[4]
            local both = math.min(old_count, new_count)

            added = added + new_count - both
            changed = changed + both
            removed = removed + old_count - both

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

    vim.b[buf].git_status_dict = state.branch and {
        head = state.branch,
        added = added,
        changed = changed,
        removed = removed,
    } or nil

    vim.cmd.redrawstatus()
end

local function git_refresh(buf)
    if not vim.api.nvim_buf_is_valid(buf) or vim.bo[buf].buftype ~= "" then return end
    if vim.fn.executable("git") ~= 1 then return end

    local path = vim.api.nvim_buf_get_name(buf)
    if path == "" then return end

    local state = git_buffers[buf] or {}
    git_buffers[buf] = state
    state.version = (state.version or 0) + 1
    local version = state.version
    local dir = vim.fs.dirname(path)

    local function receive(field, transform)
        return function(result)
            vim.schedule(function()
                if not vim.api.nvim_buf_is_valid(buf) or git_buffers[buf] ~= state
                    or state.version ~= version or vim.api.nvim_buf_get_name(buf) ~= path then
                    return
                end
                state[field] = transform(result)
                git_draw(buf)
            end)
        end
    end

    vim.system({ "git", "-C", dir, "show", ":./" .. vim.fs.basename(path) }, { text = true },
        receive("base", function(result)
            return result.code == 0 and result.stdout or nil
        end))

    vim.system({ "git", "-C", dir, "rev-parse", "--abbrev-ref", "HEAD" }, { text = true },
        receive("branch", function(result)
            return result.code == 0 and (result.stdout or ""):match("[^\r\n]+") or nil
        end))
end

local function git_schedule(buf)
    local state = git_buffers[buf]
    if not state then return end
    state.update = (state.update or 0) + 1
    local update = state.update

    vim.defer_fn(function()
        if git_buffers[buf] == state and state.update == update then
            git_draw(buf)
        end
    end, 200)
end

vim.api.nvim_create_autocmd({ "BufEnter", "BufReadPost", "BufWritePost", "FocusGained" }, {
    group = git_group,
    callback = function(args) git_refresh(args.buf) end,
})

vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
    group = git_group,
    callback = function(args) git_schedule(args.buf) end,
})

vim.api.nvim_create_autocmd("BufWipeout", {
    group = git_group,
    callback = function(args) git_buffers[args.buf] = nil end,
})

vim.schedule(function() git_refresh(vim.api.nvim_get_current_buf()) end)

-- floaterminal

local state = {
    floating = {
        buf = -1,
        win = -1,
    }
}
local function create_floating_window(opts)
    opts = opts or {}
    local width = opts.width or math.floor(vim.o.columns * 0.8)
    local height = opts.height or math.floor(vim.o.lines * 0.8)

    local col = math.floor((vim.o.columns - width) / 2)
    local row = math.floor((vim.o.lines - height) / 2)

    local buf = nil
    if vim.api.nvim_buf_is_valid(opts.buf) then
        buf = opts.buf
    else
        buf = vim.api.nvim_create_buf(false, true)
    end

    local win = vim.api.nvim_open_win(buf, true, {
        relative = "editor",
        width = width,
        height = height,
        col = col,
        row = row,
        style = "minimal",
        border = "bold",
        title = "floaterminal",
        title_pos = "left",
        footer = "1337est",
        footer_pos = "right",
    })

    return { buf = buf, win = win }
end

local toggle_terminal = function()
    if not vim.api.nvim_win_is_valid(state.floating.win) then
        state.floating = create_floating_window { buf = state.floating.buf }
        if vim.bo[state.floating.buf].buftype ~= "terminal" then
            vim.cmd.term()
            state.floating.buf = vim.api.nvim_get_current_buf()
        end
    else
        vim.api.nvim_win_hide(state.floating.win)
    end
end
vim.api.nvim_create_user_command("Floaterminal", toggle_terminal, {})

vim.keymap.set({ "n", "t" }, "<leader>tt", toggle_terminal, { desc = "1337: toggle terminal" })
vim.keymap.set("t", "<esc><esc>", "<c-\\><c-n>", { desc = "1337: normal mode" })

-- autopairs

local autopairs = {
    ["("] = ")",
    ["["] = "]",
    ["{"] = "}",
    ['"'] = '"',
    ["'"] = "'",
    ["`"] = "`",
}

local function next_char()
    local line = vim.api.nvim_get_current_line()
    local col = vim.api.nvim_win_get_cursor(0)[2]
    return line:sub(col + 1, col + 1)
end

for open, close in pairs(autopairs) do
    vim.keymap.set("i", open, function()
        if open == close and next_char() == close then
            return "<Right>"
        end
        return open .. close .. "<Left>"
    end, { expr = true })

    if open ~= close then
        vim.keymap.set("i", close, function()
            return next_char() == close and "<Right>" or close
        end, { expr = true })
    end
end

vim.keymap.set("i", "<BS>", function()
    local line = vim.api.nvim_get_current_line()
    local col = vim.api.nvim_win_get_cursor(0)[2]
    return autopairs[line:sub(col, col)] == line:sub(col + 1, col + 1)
        and "<Del><BS>" or "<BS>"
end, { expr = true })

-- statusline



local function stl_escape(value)
    return value:gsub("%%", "%%%%")
end

function _G.StatuslineMode()
    local mode = mode_info()
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

vim.opt.laststatus = 3
vim.o.statusline = table.concat({
    "%{%v:lua.StatuslineMode()%}",
    "%{%v:lua.StatuslineGit()%}",
    "%{%v:lua.StatuslineDiagnostics()%}",
    "%{%v:lua.StatuslineFile()%}",
    "%=",
    "[%l / %L],%c %3p%% ",
})

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

vim.o.tabline = "%!v:lua.Tabline()"

-- winbar

vim.o.winbar = " %f%=%{get(w:, 'remote_host', hostname())} "

-- ui refresh

local ui_grp = vim.api.nvim_create_augroup("1337.ui", { clear = true })

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

-- mode to map commands

local function show_mappings(requested_mode)
    local mode = mode_info(requested_mode).map

    local mappings = {}

    for _, map in ipairs(vim.api.nvim_get_keymap(mode)) do
        mappings[map.lhs:gsub(" ", "<Space>")] = map
    end

    for _, map in ipairs(vim.api.nvim_buf_get_keymap(0, mode)) do
        mappings[map.lhs:gsub(" ", "<Space>")] = map
    end

    local keys = vim.tbl_keys(mappings)
    table.sort(keys)

    local width_key = 0
    for _, key in ipairs(keys) do
        width_key = math.max(width_key, #key)
    end

    local lines = {}

    for _, key in ipairs(keys) do
        local map = mappings[key]
        local description = map.desc

        if not description or description == "" then
            description = (map.rhs and map.rhs ~= "") and map.rhs or "[Lua callback]"
        end

        description = description:gsub("[\r\n]", " ")

        lines[#lines + 1] = string.format(
            " %-" .. width_key .. "s  %s",
            key,
            description
        )
    end

    if #lines == 0 then
        lines = { " No mappings" }
    end

    vim.schedule(function()
        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

        vim.bo[buf].modifiable = false
        vim.bo[buf].bufhidden = "wipe"

        local width = math.min(100, math.max(1, vim.o.columns - 4))
        local height = math.min(#lines, math.max(1, vim.o.lines - 6))

        local win = vim.api.nvim_open_win(buf, true, {
            relative = "editor",
            width = width,
            height = height,
            row = math.floor((vim.o.lines - height) / 2),
            col = math.floor((vim.o.columns - width) / 2),
            style = "minimal",
            border = "rounded",
            title = " " .. mode .. " mappings ",
            title_pos = "center",
        })

        vim.wo[win].wrap = false
        vim.wo[win].cursorline = true

        for _, key in ipairs({ "q", "<Esc>" }) do
            vim.keymap.set("n", key, function()
                if vim.api.nvim_win_is_valid(win) then
                    vim.api.nvim_win_close(win, true)
                end
            end, { buffer = buf, silent = true })
        end
    end)
end

vim.keymap.set({ "n", "x", "s", "o" }, "<leader>m", show_mappings, {
    silent = true,
    desc = "Show current mode mappings",
})

for mode, escape in pairs({
    i = "<Esc>",
    c = "<C-c>",
    t = "<C-\\><C-n>",
}) do
    vim.keymap.set(mode, "<F6>", function()
        show_mappings(mode)
        return escape
    end, {
        expr = true,
        silent = true,
        desc = "Show current mode mappings",
    })
end

-- zspd

require("zspd").setup({
    cmd = "zspd",
    zig = "zig",
    build_graph = true,

    mappings = {
        definition = "gd",
        completion = false,
        symbols = "<leader>zs",
    },

    diagnostics = false,
})
