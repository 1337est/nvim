-- settings

vim.g.mapleader = " "
vim.g.maplocalleader = " "
vim.g.have_nerd_font = true

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

-- vim.g.clipboard = {
--     name = "lemonade",
--     copy = { ["+"] = "lemonade copy", ["*"] = "lemonade copy", },
--     paste = { ["+"] = "lemonade paste", ["*"] = "lemonade paste", },
--     cache_enabled = 0,
-- }
vim.schedule(function() vim.opt.clipboard = "unnamedplus" end)

vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.inccommand = "split"
vim.opt.iskeyword:append("-")

vim.opt.updatetime = 300
vim.opt.timeoutlen = 300

vim.opt.completeopt = "menuone,noinsert,noselect"
vim.opt.pumheight = 10
vim.opt.pumblend = 15

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

local cwd = vim.uv.cwd()
if not cwd or vim.fn.isdirectory(cwd) == 0 then
    vim.cmd.cd(vim.fn.expand("~"))
end

local site_dir = vim.fn.stdpath("data") .. "/site"
if not vim.o.packpath:find(site_dir, 1, true) then
    vim.opt.packpath:prepend(site_dir)
end

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
                "WinEnter",
                "BufEnter",
                "BufWritePost",
                "SessionLoadPost",
                "FileChangedShellPost",
                "VimResized",
                "Filetype",
                "CursorMoved",
                "CursorMovedI",
                "ModeChanged",
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

require("monokai-pro").setup({})
vim.cmd.colorscheme("monokai-pro-octagon")

require("oil").setup({})
vim.keymap.set("n", "<leader>e", "<cmd>Oil<cr>", { silent = true, desc = "OIL: Explorer" })

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

require("which-key").setup({})
vim.keymap.set("n", "<leader>?", function()
    require("which-key").show({ global = false })
end, { desc = "Buffer Local Keymaps (which-key)" })

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
vim.keymap.set("t", "<esc><esc>", "<c-\\><c-n>")

-- highlighter

if vim.g.loaded_1337_word_highlights then
    return
end
vim.g.loaded_1337_word_highlights = true

local api                         = vim.api
local ns                          = api.nvim_create_namespace("1337.comment_tags")

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

local function define_signs()
    for _, tag in ipairs(TAGS) do
        local sign_name = tag.hl .. "Sign"

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

local function highlight_range(bufnr, srow, erow)
    bufnr = bufnr or 0
    if not api.nvim_buf_is_loaded(bufnr) then
        return
    end

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

        highlight_hex_colors(bufnr, row, line)
    end
end

local function refresh(bufnr)
    highlight_range(bufnr or 0, 0, -1)
end

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

pcall(refresh, 0)

-- utils

P = function(v)
    print(vim.inspect(v))
    return v
end
