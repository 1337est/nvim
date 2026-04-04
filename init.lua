-- utils

P = function(v)
    print(vim.inspect(v))
    return v
end

-- settings

vim.g.mapleader = " "
vim.g.maplocalleader = " "
vim.g.have_nerd_font = true
vim.g.loaded_1337_word_highlights = true
-- vim.g.clipboard = {
--     name = "lemonade",
--     copy = { ["+"] = "lemonade copy", ["*"] = "lemonade copy", },
--     paste = { ["+"] = "lemonade paste", ["*"] = "lemonade paste", },
--     cache_enabled = 0,
-- }

vim.schedule(function() vim.opt.clipboard = "unnamedplus" end)

vim.opt.number = true
vim.opt.relativenumber = true

vim.opt.foldlevel = 99

vim.opt.cursorline = true
vim.opt.colorcolumn = "100"

vim.opt.expandtab = true
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.smartindent = true

vim.opt.list = true
vim.opt.listchars = { tab = "<->", trail = ".", nbsp = "-" }

vim.opt.showmode = false
vim.opt.showtabline = 2
vim.o.winbar = "%f"

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
        format = function(diagnostic)
            local diagnostic_message = {
                [vim.diagnostic.severity.ERROR] = diagnostic.message,
                [vim.diagnostic.severity.WARN] = diagnostic.message,
                [vim.diagnostic.severity.INFO] = diagnostic.message,
                [vim.diagnostic.severity.HINT] = diagnostic.message,
            }
            return diagnostic_message[diagnostic.severity]
        end,
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
    "hyprls",
    "lua_ls",
    "nushell",
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

-- vim.pack

vim.pack.add({
    { src = "https://github.com/windwp/nvim-autopairs" },
    { src = "https://github.com/Saghen/blink.cmp", version = vim.version.range("1"), },
    { src = "https://github.com/lewis6991/gitsigns.nvim" },
    { src = "https://github.com/nvim-tree/nvim-web-devicons" },
    { src = "https://github.com/nvim-lualine/lualine.nvim" },
    { src = "https://github.com/OXY2DEV/markview.nvim" },
    { src = "https://github.com/loctvl842/monokai-pro.nvim" },
    { src = "https://github.com/stevearc/oil.nvim" },
    { src = "https://github.com/nvim-lua/plenary.nvim" },
    { src = "https://github.com/nvim-telescope/telescope.nvim", version = "v0.2.0", },
    { src = "https://github.com/nvim-treesitter/nvim-treesitter" },
    { src = "https://github.com/folke/which-key.nvim" },
}, {
    load = true,
})

require("nvim-autopairs").setup()

require("blink.cmp").setup({
    keymap = { preset = "default" },
    appearance = { nerd_font_variant = "mono", },
    completion = { documentation = { auto_show = false }, },
    sources = { default = { "lsp", "path", "snippets", "buffer" }, },
    fuzzy = { implementation = "prefer_rust_with_warning", },
})

require("gitsigns").setup({})

local lualine_pos = function()
    local l = vim.fn.line(".")
    local L = vim.fn.line("$")
    local c = vim.fn.col(".")
    local p = (L > 0) and math.floor((l / L) * 100) or 0
    return string.format("[%d/%d],%d %3d%%%%", l, L, c, p)
end

local lualine_abcxyz = function(a, b, c, x, y, z)
    return {
        lualine_a = a or {},
        lualine_b = b or {},
        lualine_c = c or {},
        lualine_x = x or {},
        lualine_y = y or {},
        lualine_z = z or {},
    }
end

require("lualine").setup({
    options = {
        icons_enabled = true,
        theme = "monokai-pro",
        component_separators = { left = "│", right = "│" },
        section_separators = { left = "", right = "" },
        disabled_filetypes = { statusline = {}, winbar = {}, },
        ignore_focus = {},
        always_divide_middle = true,
        always_show_tabline = true,
        globalstatus = true,
        refresh = {
            statusline = 1000,
            tabline = 1000,
            winbar = 1000,
            refresh_time = 16,
            events = {
                "WinEnter", "BufEnter", "BufWritePost", "SessionLoadPost", "FileChangedShellPost",
                "VimResized", "Filetype", "CursorMoved", "CursorMovedI", "ModeChanged"
            },
        },
    },
    sections = lualine_abcxyz(
        { "mode" },
        { "branch", "diff", "diagnostics" },
        { { "filename", path = 1 } },
        { { "filetype", colored = false, icon_only = false, icon = { align = "right" } } },
        { "hostname" },
        { lualine_pos }
    ),
    inactive_sections = lualine_abcxyz(),
    winbar = lualine_abcxyz({ { "filename", path = 4 } }, {}, {}, {}, {}, { "branch" }),
    inactive_winbar = lualine_abcxyz({}, {}, { { "filename", path = 4 } }, { "branch" }),
    tabline = lualine_abcxyz({ "branch" }, { "datetime" }, { "lsp_status" }, {}, {}, { "tabs" }),
    extensions = { "oil" },
})

require("oil").setup({})
vim.keymap.set("n", "<leader>e", "<cmd>Oil<cr>", { silent = true, desc = "OIL: Explorer" })

require("which-key").setup({})
vim.keymap.set("n", "<leader>?", function()
    require("which-key").show({ global = false })
end, { desc = "Buffer Local Keymaps (which-key)" })

-- colorscheme

require("monokai-pro").setup({})
vim.cmd.colorscheme("monokai-pro-octagon")

-- treesitter

local treesitter_filetypes = {
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
    "vimdoc"
}
local treesitter_ft_grp = vim.api.nvim_create_augroup("1337.treesitter.filetypes", { clear = true })

require("nvim-treesitter").setup {
    install_dir = vim.fn.stdpath("data") .. "/site",
}
require("nvim-treesitter").install(treesitter_filetypes)

vim.api.nvim_create_autocmd("FileType", {
    group = treesitter_ft_grp,
    pattern = treesitter_filetypes,
    callback = function()
        vim.treesitter.start()
        vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
    end,
})

local treesitter_pack_grp = vim.api.nvim_create_augroup("1337.treesitter.pack", { clear = true })
vim.api.nvim_create_autocmd("PackChanged", {
    group = treesitter_pack_grp,
    callback = function(ev)
        if ev.data.spec.name == "nvim-treesitter" and (ev.data.kind == "install" or ev.data.kind == "update") then
            if not ev.data.active then
                vim.cmd.packadd("nvim-treesitter")
            end
            pcall(vim.cmd, "TSUpdate")
        end
    end,
})

-- utils_highlighter && tag_highlighter && hex_highlighter
-- TODO: Add gutter symbols

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
    vim.schedule(function()
        bufnr = (bufnr == nil or bufnr == 0) and vim.api.nvim_get_current_buf() or bufnr
        if vim.api.nvim_buf_is_valid(bufnr) then
            fn(bufnr)
        end
    end)
end

-- tag_highlighter

local tag_hi_ns = vim.api.nvim_create_namespace("1337.tag_highlighter")

local hi_tags = {
    { hl = "1337TagTODO", bg = "#a761c4", words = { "TODO:", "LLO:", "START:", "END:", "HERE:" } },
    { hl = "1337TagTEST", bg = "#3b6bb5", words = { "TEST:", "EXP:", "TEMP:" } },
    { hl = "1337TagPASS", bg = "#6fae47", words = { "PASS:" } },
    { hl = "1337TagPERF", bg = "#ffd76d", words = { "PERF:", "OPTIM:" } },
    { hl = "1337TagFAIL", bg = "#f63b34", words = { "FAIL:", "ERROR:", "FIXME:", "BUG:" } },
    { hl = "1337TagWARN", bg = "#ff8800", words = { "WARNING:", "HACK:", "CAUTION:" } },
    { hl = "1337TagNOTE", bg = "#38728a", words = { "NOTE:", "INFO:", "NEW:", "OLD:" } },
}

local function define_tag_highlights()
    for _, tag in ipairs(hi_tags) do
        vim.api.nvim_set_hl(0, tag.hl, {
            fg = hi_util.fg_for(tag.bg),
            bg = tag.bg,
            bold = true,
            force = true,
        })
    end
end

local function refresh_tag_highlights(bufnr)
    local api = vim.api
    bufnr = (bufnr == nil or bufnr == 0) and api.nvim_get_current_buf() or bufnr
    if not api.nvim_buf_is_loaded(bufnr) then
        return
    end

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

vim.api.nvim_create_autocmd("ColorScheme", {
    group = tag_hi_grp,
    callback = function()
        define_tag_highlights()
        hi_util.schedule_buf(refresh_tag_highlights, 0)
    end,
    desc = "1337: reapply comment tag highlights",
})

define_tag_highlights()
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
    bufnr = (bufnr == nil or bufnr == 0) and api.nvim_get_current_buf() or bufnr
    if not api.nvim_buf_is_loaded(bufnr) then
        return
    end

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
        hex_hi_groups = {}
        hi_util.schedule_buf(refresh_hex_highlights, 0)
    end,
    desc = "1337: reapply hex color highlights",
})

hi_util.schedule_buf(refresh_hex_highlights, 0)

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
        end
    else
        vim.api.nvim_win_hide(state.floating.win)
    end
end
vim.api.nvim_create_user_command("Floaterminal", toggle_terminal, {})

vim.keymap.set({ "n", "t" }, "<leader>tt", toggle_terminal, { desc = "1337: toggle terminal" })
vim.keymap.set("t", "<esc><esc>", "<c-\\><c-n>", { desc = "1337: normal mode" })
