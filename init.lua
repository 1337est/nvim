-- ###############
-- # My settings #
-- ###############

vim.g.mapleader = " "
vim.g.maplocalleader = " "
vim.g.have_nerd_font = true

-- gutter
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.signcolumn = "yes"
vim.opt.foldcolumn = "1"
vim.opt.foldmethod = "indent"
-- vim.opt.foldexpr = "nvim_treesitter#foldexpr()"
vim.opt.foldlevel = 99

-- row/column indicators
vim.opt.cursorline = true
vim.opt.colorcolumn = "100"

-- gui
vim.opt.termguicolors = true
vim.opt.guicursor = ""

-- render
vim.opt.lazyredraw = true

-- whitespace
vim.opt.expandtab = true
vim.opt.shiftwidth = 4
vim.opt.tabstop = 4
vim.opt.smartindent = true

-- conceal
vim.opt.conceallevel = 0
vim.opt.concealcursor = ""
vim.opt.list = true
vim.opt.listchars = { tab = "<->", trail = ".", nbsp = "-" }

-- statusline / windows / tabs
vim.opt.showmode = false
vim.opt.laststatus = 3
vim.opt.showtabline = 2
vim.opt.ruler = true
vim.o.winbar = "%f"
vim.o.tabline = ""

vim.opt.autoread = true
vim.opt.autowrite = false
vim.opt.autochdir = false
vim.opt.confirm = true

vim.opt.splitright = true
vim.opt.splitbelow = true
vim.opt.winblend = 10

vim.opt.wrap = false
vim.opt.spell = false
vim.opt.linebreak = true
vim.opt.scrolloff = 1
vim.opt.sidescrolloff = 1

-- undo state
vim.opt.undodir = vim.fn.stdpath("state") .. "/undodir//"
vim.opt.undofile = true

-- view state
vim.opt.viewdir = vim.fn.stdpath("state") .. "/viewdir//"

-- backup state
vim.opt.backup = false
vim.opt.writebackup = false

-- swap state
vim.opt.swapfile = false

-- clipboard
vim.schedule(function()
    vim.opt.clipboard = "unnamedplus"
end)

-- searching
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.incsearch = true
vim.opt.inccommand = "split"
vim.opt.hlsearch = true
vim.opt.iskeyword:append("-")

-- mouse
vim.opt.mouse = "a"
vim.opt.mousescroll = "ver:1,hor:1"

-- completions
vim.opt.updatetime = 250
vim.opt.timeoutlen = 300
vim.opt.completeopt = "menuone,noinsert,noselect"
vim.opt.pumheight = 10
vim.opt.pumblend = 10

-- ###########
-- # Keymaps #
-- ###########

-- paste over without yanking / delete without yanking
vim.keymap.set("x", "<leader>p", [["_dP]], { silent = true, desc = "1337: paste over without yanking" })
vim.keymap.set({ "n", "v" }, "<leader>d", [["_d]], { silent = true, desc = "1337: delete without yanking" })

vim.keymap.set("n", "<leader><C-l>", "<cmd>nohlsearch<cr>", { silent = true, desc = "1337: Clears search highlights" })

-- keep search results centered
vim.keymap.set("n", "<C-u>", "<C-u>zz", { silent = true, desc = "1337: Half page up centered" })
vim.keymap.set("n", "<C-d>", "<C-d>zz", { silent = true, desc = "1337: Half page down centered" })
vim.keymap.set("n", "<C-f>", "<C-f>zz", { silent = true, desc = "1337: Full page up centered" })
vim.keymap.set("n", "<C-b>", "<C-b>zz", { silent = true, desc = "1337: Full page down centered" })
vim.keymap.set("n", "J", "mzJ`z", { silent = true, desc = "1337: Join lines, keep cursor position" })

-- Moving blocks of text with active selection via alt keys
vim.keymap.set("n", "<A-j>", ":m .+1<CR>==", { silent = true, desc = "1337: Move line down" })
vim.keymap.set("n", "<A-k>", ":m .-2<CR>==", { silent = true, desc = "1337: Move line up" })
vim.keymap.set("v", "<A-j>", ":m '>+1<CR>gv=gv", { silent = true, desc = "1337: Move selection down" })
vim.keymap.set("v", "<A-k>", ":m '<-2<CR>gv=gv", { silent = true, desc = "1337: Move selection up" })
vim.keymap.set("v", "<A-.>", ">gv", { silent = true, desc = "1337: Indent right reselect" })
vim.keymap.set("v", "<A-,>", "<gv", { silent = true, desc = "1337: Indent left reselect" })

-- File explorer
vim.keymap.set("n", "<leader>e", "<cmd>Oil<cr>", { silent = true, desc = "OIL: Explorer" })

-- ################
-- # Autocommands #
-- ################

-- Automatic mkview and loadview behavior
local fold_remember_on_leave = vim.api.nvim_create_augroup("1337.fold_remember_on_leave", { clear = true })
vim.api.nvim_create_autocmd("BufWinLeave", {
    group = fold_remember_on_leave,
    pattern = "*.*",
    command = "mkview",
    desc = "1337: Remembers folds on window leave",
})

local fold_remember_on_enter = vim.api.nvim_create_augroup("1337.fold_remember_on_enter", { clear = true })
vim.api.nvim_create_autocmd("BufWinEnter", {
    group = fold_remember_on_enter,
    pattern = "*.*",
    command = "silent! loadview",
    desc = "1337: Remembers folds on window enter",
})

-- Highlights on yank
local hl_on_yank = vim.api.nvim_create_augroup("1337.hl_on_yank", { clear = true })
vim.api.nvim_create_autocmd("TextYankPost", {
    group = hl_on_yank,
    pattern = "*",
    callback = function()
        vim.hl.on_yank({ higroup = "IncSearch", timeout = 40 })
    end,
    desc = "1337: Brief highlight on yank",
})

-- formatting
local format_opts_remove_cro = vim.api.nvim_create_augroup("1337.format_opts_remove_cro", { clear = true })
vim.api.nvim_create_autocmd("BufEnter", {
    group = format_opts_remove_cro,
    pattern = "*",
    callback = function()
        vim.opt.formatoptions:remove({ "c", "r", "o" })
    end,
    desc = "1337: Removes automatic continuation comments when entering a buffer",
})

-- Spell check and word wrap on these filetypes
local ft_wrap_spell = vim.api.nvim_create_augroup("1337.ft_wrap_spell", { clear = true })
vim.api.nvim_create_autocmd("FileType", {
    group = ft_wrap_spell,
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

-- ###############
-- # Diagnostics #
-- ###############

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

-- #######
-- # LSP #
-- #######

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

-- #####################
-- # Builtin vim.pack  #
-- #####################

-- Ensure vim.pack has a valid cwd for git
local cwd = vim.uv.cwd()
if not cwd or vim.fn.isdirectory(cwd) == 0 then
    vim.cmd.cd(vim.fn.expand("~"))
end

-- Ensure vim.pack can use stdpath("data")/site
local site_dir = vim.fn.stdpath("data") .. "/site"
if not vim.o.packpath:find(site_dir, 1, true) then
    vim.opt.packpath:prepend(site_dir)
end

-- autopairs
vim.pack.add({
    { src = "https://github.com/windwp/nvim-autopairs" },
}, {
    load = true,
})
require("nvim-autopairs").setup()

-- blink.cmp
vim.pack.add({
    {
        src = "https://github.com/Saghen/blink.cmp",
        version = vim.version.range("1"),
    },
}, {
    load = true,
})
require("blink.cmp").setup({
    keymap = { preset = "default" },
    appearance = {
        nerd_font_variant = "mono",
    },
    completion = {
        documentation = { auto_show = false },
    },
    sources = {
        default = { "lsp", "path", "snippets", "buffer" },
    },
    fuzzy = {
        implementation = "prefer_rust_with_warning",
    },
})

-- gitsigns
vim.pack.add({
    { src = "https://github.com/lewis6991/gitsigns.nvim" },
}, {
    load = true,
})
require("gitsigns").setup({})

-- devicons
vim.pack.add({
    { src = "https://github.com/nvim-tree/nvim-web-devicons" },
}, {
    load = true,
})

-- lualine
vim.pack.add({
    { src = "https://github.com/nvim-lualine/lualine.nvim" },
}, {
    load = true,
})
require("lualine").setup({
    options = {
        icons_enabled = true,
        theme = "monokai-pro",
        component_separators = { left = "│", right = "│" },
        section_separators = { left = "", right = "" },
        disabled_filetypes = {
            statusline = {},
            winbar = {},
        },
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

    sections = {
        lualine_a = { "mode" },
        lualine_b = { "branch", "diff", "diagnostics" },
        lualine_c = {
            {
                "filename",
                path = 1,
            },
        },
        lualine_x = {
            {
                "filetype",
                colored = false,
                icon_only = false,
                icon = { align = "right" },
            },
        },
        lualine_y = { "hostname" },
        lualine_z = {
            function()
                local l = vim.fn.line(".")
                local L = vim.fn.line("$")
                local c = vim.fn.col(".")
                local p = 0

                if L > 0 then
                    p = math.floor((l / L) * 100)
                end

                return string.format("[%d/%d],%d %3d%%%%", l, L, c, p)
            end,
        },
    },

    inactive_sections = {
        lualine_a = {},
        lualine_b = {},
        lualine_c = {},
        lualine_x = {},
        lualine_y = {},
        lualine_z = {},
    },

    winbar = {
        lualine_a = {
            {
                "filename",
                path = 4,
            },
        },
        lualine_b = {},
        lualine_c = {},
        lualine_x = {},
        lualine_y = {},
        lualine_z = { "branch" },
    },

    inactive_winbar = {
        lualine_a = {},
        lualine_b = {},
        lualine_c = {
            {
                "filename",
                path = 4,
            },
        },
        lualine_x = { "branch" },
        lualine_y = {},
        lualine_z = {},
    },

    tabline = {
        lualine_a = { "branch" },
        lualine_b = { "datetime" },
        lualine_c = { "lsp_status" },
        lualine_x = {},
        lualine_y = {},
        lualine_z = { "tabs" },
    },

    extensions = { "oil" },
})

-- markview
vim.pack.add({
    { src = "https://github.com/OXY2DEV/markview.nvim" },
}, {
    load = true,
})

-- monokai-pro
vim.pack.add({
    { src = "https://github.com/loctvl842/monokai-pro.nvim" },
}, {
    load = true,
})
require("monokai-pro").setup({})
vim.cmd.colorscheme("monokai-pro-octagon")

-- oil
vim.pack.add({
    { src = "https://github.com/stevearc/oil.nvim" },
}, {
    load = true,
})
require("oil").setup({})

-- plenary
vim.pack.add({
    { src = "https://github.com/nvim-lua/plenary.nvim" },
}, {
    load = true,
})

-- telescope
vim.pack.add({
    {
        src = "https://github.com/nvim-telescope/telescope.nvim",
        version = "v0.2.0",
    },
}, {
    load = true,
})

-- treesitter
vim.pack.add({
    { src = "https://github.com/nvim-treesitter/nvim-treesitter" },
}, {
    load = true,
})

require("nvim-treesitter").setup({
    install_dir = vim.fn.stdpath("data") .. "/site",
    ensure_installed = {
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
    },
})

vim.api.nvim_create_autocmd("FileType", {
    pattern = {
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
    },
    callback = function()
        vim.treesitter.start()
    end,
})

vim.api.nvim_create_autocmd("FileType", {
    pattern = {
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
    },
    callback = function()
        vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
    end,
})

local treesitter_pack_grp = vim.api.nvim_create_augroup("1337.treesitter_pack", { clear = true })
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

-- which-key
vim.pack.add({
    { src = "https://github.com/folke/which-key.nvim" },
}, {
    load = true,
})
require("which-key").setup({})
vim.keymap.set("n", "<leader>?", function()
    require("which-key").show({ global = false })
end, { desc = "Buffer Local Keymaps (which-key)" })

-- #######################
-- # Personal Lua things #
-- #######################

require("plugins.leet.floaterminal")
require("plugins.leet.highlighter")
require("plugins.utils")
