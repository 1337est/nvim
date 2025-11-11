-- =============== Helper Functions ===============

local autocmd = vim.api.nvim_create_autocmd
local function aug(name) return vim.api.nvim_create_augroup("1337." .. name, { clear = true }) end

local function map(args)
    assert(type(args) == "table", "map() expects a table")

    local mode = args.mode or error("Missing 'mode' in map()")
    local keys = args.keys or error("Missing 'keys' in map()")
    local fn = args.fn or error("Missing 'fn' in map()")
    local desc = args.desc or error("Missing 'desc' in map()")
    local prefix = args.prefix or "1337"

    local opts = vim.tbl_extend("force", {
        noremap = true,
        silent = true,
        desc = ("%s: %s"):format(prefix, desc),
    }, args.opts or {})

    vim.keymap.set(mode, keys, fn, opts)
end

-- =============== Globals ===============
vim.g.mapleader = " " -- Sets space as the leader key
vim.g.maplocalleader = " " -- Sets space as the leader key
vim.g.have_nerd_font = true -- For my nerd font
vim.cmd.colorscheme("1337dark") -- check out colors/1337dark.lua

-- Search settings
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.incsearch = true -- Shows pattern match as you type
vim.opt.inccommand = "split" -- preview substitutions live as you type
vim.opt.hlsearch = true -- Set highlight on search
vim.opt.iskeyword:append("-")
-- Set highlight on search, but clear on pressing <Esc> in normal mode
map({
    mode = "n", keys = "<Esc>", fn = "<cmd>nohlsearch<CR>", desc = "Clear hl from search",
})

-- Window split behavior
vim.opt.splitright = true -- new splits open right
vim.opt.splitbelow = true -- new splits open below
-- Floating windows
vim.opt.winblend = 10

-- Basics
vim.opt.number = true -- Make line numbers default
vim.opt.relativenumber = true -- Shows line # away from current line #
vim.opt.signcolumn = "yes" -- Show sign column
vim.opt.termguicolors = true -- Enables 24-bit RGB color
vim.opt.guicursor = "" -- Disable cursor styling
vim.opt.lazyredraw = true
vim.opt.updatetime = 300 -- Faster completion
vim.opt.timeoutlen = 500 -- Mapped key sequence wait time
vim.opt.mouse = "a" -- Enables mouse mode
vim.opt.mousescroll = "ver:1,hor:1"
vim.opt.confirm = true
-- Indicator / hl-lines
vim.opt.cursorline = true -- Show which line your cursor is on
vim.opt.colorcolumn = "100" -- Line at the nth column
-- automatic behavior
vim.opt.autoread = true
vim.opt.autowrite = false
vim.opt.autochdir = false

-- Indent / text
vim.opt.expandtab = true -- Use appropriate spaces to insert tabs
vim.opt.shiftwidth = 4 -- 4 spaces for (auto)indenting
vim.opt.tabstop = 4 -- tabs are 4 spaces
vim.opt.smartindent = true -- Smart auto-indenting on new lines
-- Text wrap behavior
vim.opt.wrap = false -- Don't wrap text
vim.opt.linebreak = true -- Wraps words instead of characters
vim.opt.scrolloff = 1 -- Minimal screen lines above/below the cursor
vim.opt.sidescrolloff = 1 -- Minimal screen lines to keep left/right

-- Conceal text
vim.opt.conceallevel = 0
vim.opt.concealcursor = ""
vim.opt.list = true
vim.opt.listchars = {
    tab = "<->", trail = ".", nbsp = "-",
}

-- Sync clipboard between OS and Neovim.
--  Remove this option if you want your OS clipboard to remain independent.
--  See `:help 'clipboard'`
vim.schedule(function()
    vim.opt.clipboard = "unnamedplus"
end)
autocmd("TextYankPost", {
    desc = "Brief highlight on yank",
    group = aug("hl_on_yank"),
    pattern = "*",
    callback = function()
        vim.hl.on_yank({
            higroup = "IncSearch",
            timeout = 40,
        })
    end,
})

-- Completions Ctrl-x-Ctrl-o
vim.opt.completeopt = "menuone,noinsert,noselect"
vim.opt.pumheight = 10
vim.opt.pumblend = 10

-- Remove auto comment continuation
-- Getting rid of auto-inserted comments
autocmd("BufEnter", {
    desc = "Remove automatic continuation comments on new line",
    group = aug("format_opts_remove_cro"),
    callback = function() vim.opt.formatoptions:remove({ "c", "r", "o" }) end,
})

-- Viewdir/folds
vim.opt.viewdir = vim.fn.stdpath("state") .. "/viewdir//"
vim.opt.foldcolumn = "1"
vim.opt.foldmethod = "indent"
-- vim.opt.foldexpr = "nvim_treesitter#foldexpr()"
vim.opt.foldlevel = 99
autocmd({ "BufWinLeave" }, {
    desc = "Remember folds on window leave",
    group = aug("fold_remember_on_leave"),
    pattern = "*.*",
    command = "mkview",
})
autocmd({ "BufWinEnter" }, {
    desc = "Remember folds on window enter",
    group = aug("fold_remember_on_enter"),
    pattern = "*.*",
    command = "silent! loadview",
})

-- undodir
vim.opt.undodir = vim.fn.stdpath("state") .. "/undodir//"
vim.opt.undofile = true -- Save undo history

-- backups
vim.opt.backup = false
vim.opt.writebackup = false

-- swapfiles
vim.opt.swapfile = false

vim.opt.showmode = false -- Don't show mode, since it's already in status line
vim.opt.laststatus = 3
vim.opt.showtabline = 2

-- Preserves text instead of replacing the register with the deleted text by
-- deleting text into the 'blackhole' register "_d.
map({
    mode = "v", keys = "<leader>p", fn = [["_dP]], desc = "[p]aste" })
map({
    mode = { "n", "v" }, keys = "<leader>d", fn = [["_d]], desc = "[d]elete" })

-- Diagnostic maps
map({
    mode = "n", keys = "[d", fn = vim.diagnostic.goto_prev, desc = "Previous [d]iagnostic" })
map({
    mode = "n", keys = "]d", fn = vim.diagnostic.goto_next, desc = "Next [d]iagnostic" })

autocmd({ "BufEnter" }, {
    desc = "Turn on text wrap and spelling for text files",
    group = aug("textfile_wrap_and_spell_on"),
    pattern = { "*.md", "*.txt", "*.norg" },
    callback = function()
        vim.opt_local.wrap = true
        vim.opt_local.spell = true
    end,
})

-- -- lazy package manager used for grabbing plugins from the internet
-- local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
-- if not (vim.uv or vim.loop).fs_stat(lazypath) then
--     local lazyrepo = "https://github.com/folke/lazy.nvim.git"
--     local out = vim.fn.system({
--         "git",
--         "clone",
--         "--filter=blob:none",
--         "--branch=stable",
--         lazyrepo,
--         lazypath
--     })
--     if vim.v.shell_error ~= 0 then
--         vim.api.nvim_echo({
--             { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
--             { out, "WarningMsg" },
--             { "\nPress any key to exit..." },
--         }, true, {})
--         vim.fn.getchar()
--         os.exit(1)
--     end
-- end ---@diagnostic disable-next-line: undefined-field
-- vim.opt.rtp:prepend(lazypath)

-- Make sure to setup `mapleader` and `maplocalleader` before
-- loading lazy.nvim so that mappings are correct.
-- This should have been done in set.lua

-- Setup lazy.nvim
-- require("lazy").setup({
--     -- Each file in lua/plugins/* should return a table with the plugins you want to install
--     spec = {
--
require("colorizer").setup()
--
--         {
--             "lewis6991/gitsigns.nvim",
--             enabled = true,
--             config = function()
--                 require("gitsigns").setup {
--                     signs = {
--                         add = { text = "+" },
--                         change = { text = "~" },
--                     },
--                     signs_staged = {
--                         add = { text = "+" },
--                         change = { text = "~" },
--                     },
--                 }
--             end,
--         },
--
--         {
--             "lukas-reineke/indent-blankline.nvim",
--             main = "ibl",
--             opts = {},
--             config = function()
--                 require("ibl").setup {
--                     exclude = { filetypes = {
--                         "lspinfo",
--                         "packer",
--                         "checkhealth",
--                         "help",
--                         "man",
--                         "gitcommit",
--                         "TelescopePrompt",
--                         "TelescopeResults",
--                         "",
--                         "dashboard",
--                     } }
--                 }
--             end,
--         },
--
--         {
--             "nvim-lualine/lualine.nvim",
--             enabled = true,
--             dependencies = { "nvim-tree/nvim-web-devicons" },
--             config = function()
--                 local symbols = { error = ' ', warn = ' ', info = ' ', hint = ' ' }
--                 require("lualine").setup {
--                     options = {
--                         theme = "auto",
--                         disabled_filetypes = {
--                             statusline = { 'NvimTree' },
--                             winbar = { 'NvimTree' },
--                         },
--                     },
--                     sections = {
--                         lualine_a = { { "mode" } },
--                         lualine_b = { { "diagnostics", symbols = symbols, color = { bg = '#232323' } } },
--                         lualine_c = { { "filename", path = 4 } },
--                         lualine_x = { {
--                             "filetype",
--                             icon = { align = 'left' }
--                         } },
--                         lualine_y = {
--                             { "branch", color = { bg = '#232323' } },
--                             { "diff", color = { bg = '#323232' } },
--                         },
--                         lualine_z = { "location", "progress" },
--                     },
--                     inactive_sections = {
--                         lualine_a = { "filename" },
--                         lualine_z = { "location", "progress" },
--                     },
--                 }
--             end,
--         },
--
--         {
--             'romgrk/barbar.nvim',
--             dependencies = {
--                 'lewis6991/gitsigns.nvim',
--                 'nvim-tree/nvim-web-devicons',
--             },
--             init = function()
--                 vim.g.barbar_auto_setup = false
--             end,
--             config = function()
--                 require("barbar").setup {}
--                 vim.api.nvim_set_hl(0, 'BufferCurrent', { fg = '#1c2526', bg = '#d0d0d0', bold = true })
--                 vim.api.nvim_set_hl(0, 'BufferCurrentSign', { fg = '#1c2526', bg = '#d0d0d0' })
--                 vim.api.nvim_set_hl(0, 'BufferCurrentMod', { fg = '#a8334c', bg = '#d0d0d0', bold = true })
--                 vim.api.nvim_set_hl(0, 'BufferVisible', { fg = '#4a5859', bg = '#e0e0e0' })
--                 vim.api.nvim_set_hl(0, 'BufferVisibleSign', { fg = '#4a5859', bg = '#e0e0e0' })
--                 vim.api.nvim_set_hl(0, 'BufferInactive', { fg = '#6b7280', bg = '#f0f0f0' })
--                 vim.api.nvim_set_hl(0, 'BufferInactiveSign', { fg = '#6b7280', bg = '#f0f0f0' })
--                 vim.api.nvim_set_hl(0, 'BufferTabpageFill', { fg = '#6b7280', bg = '#f5f5f5' })
--             end,
--         },
--
--         {
--             "iamcco/markdown-preview.nvim",
--             ft = { "markdown" },
--             config = function()
--                 vim.fn["mkdp#util#install"]()
--             end,
--         },
--
--         {
--             -- fuzzy finder for files
--             "nvim-telescope/telescope.nvim",
--             event = "VimEnter",
--             branch = "0.1.x",
--             dependencies = {
--                 "nvim-lua/plenary.nvim",
--                 {
--                     "nvim-telescope/telescope-fzf-native.nvim",
--                     build = "make",
--                     cond = function()
--                         return vim.fn.executable("make") == 1
--                     end,
--                 },
--                 { "nvim-telescope/telescope-ui-select.nvim" },
--                 { "nvim-tree/nvim-web-devicons", enabled = vim.g.have_nerd_font },
--             },
--             config = function()
--                 require("telescope").setup {
--                     extensions = {
--                         ["ui-select"] = { require("telescope.themes").get_dropdown() },
--                     },
--                     pickers = {
--                         find_files = {
--                             hidden = true,
--                             no_ignore = true,
--                             no_ignore_parent = true,
--                         },
--                     },
--                     defaults = {
--                         file_ignore_patterns = {
--                             "undodir",
--                             "node_modules",
--                         },
--                     },
--                 }
--                 -- Enable Telescope extensions if they are installed
--                 pcall(require("telescope").load_extension, "fzf")
--                 pcall(require("telescope").load_extension, "ui-select")
--                 -- keymaps to call telescope functions
--                 local tel = require("telescope.builtin")
--                 map({
--                     mode = "n",
--                     keys = "<leader>sh",
--                     fn = tel.help_tags,
--                     desc = "[s]earch [h]elp",
--                     prefix = "TEL"
--                 })
--                 map({
--                     mode = "n",
--                     keys = "<leader>sk",
--                     fn = tel.keymaps,
--                     desc = "[s]earch [k]eymaps",
--                     prefix = "TEL"
--                 })
--                 map({
--                     mode = "n",
--                     keys = "<leader>sf",
--                     fn = tel.find_files,
--                     desc = "[s]earch [f]iles",
--                     prefix = "TEL"
--                 })
--                 map({
--                     mode = "n",
--                     keys = "<leader>ss",
--                     fn = tel.builtin,
--                     desc = "[s]earch [s]elect Telescope",
--                     prefix = "TEL"
--                 })
--                 map({
--                     mode = "n",
--                     keys = "<leader>sw",
--                     fn = tel.grep_string,
--                     desc = "[s]earch current [w]ord",
--                     prefix = "TEL"
--                 })
--                 map({
--                     mode = "n",
--                     keys = "<leader>sg",
--                     fn = tel.live_grep,
--                     desc = "[s]earch by [g]rep",
--                     prefix = "TEL"
--                 })
--                 map({
--                     mode = "n",
--                     keys = "<leader>sd",
--                     fn = tel.diagnostics,
--                     desc = "[s]earch [d]iagnostics",
--                     prefix = "TEL"
--                 })
--                 map({
--                     mode = "n",
--                     keys = "<leader>sr",
--                     fn = tel.resume,
--                     desc = "[s]earch [r]esume",
--                     prefix = "TEL"
--                 })
--                 map({
--                     mode = "n",
--                     keys = "<leader>s.",
--                     fn = tel.oldfiles,
--                     desc = "[s]earch Recent Files ('.' for repeat)",
--                     prefix = "TEL"
--                 })
--                 map({
--                     mode = "n",
--                     keys = "<leader><leader>",
--                     fn = tel.buffers,
--                     desc = "[ ] Find existing buffers",
--                     prefix = "TEL"
--                 })
--
--                 -- Search in current buffer
--                 map({
--                     mode = "n",
--                     keys = "<leader>/",
--                     fn = function()
--                         tel.current_buffer_fuzzy_find(require("telescope.themes").get_dropdown({
--                             winblend = 10,
--                             previewer = false,
--                         }))
--                     end,
--                     desc = "[/] Fuzzily search in current buffer",
--                     prefix = "TEL",
--                 })
--
--                 -- Search open files
--                 map({
--                     mode = "n",
--                     keys = "<leader>s/",
--                     fn = function()
--                         tel.live_grep({
--                             grep_open_files = true,
--                             prompt_title = "Live Grep in Open Files",
--                         })
--                     end,
--                     desc = "[s]earch [/] in Open Files",
--                     prefix = "TEL",
--                 })
--
--                 -- Search your Neovim config
--                 map({
--                     mode = "n",
--                     keys = "<leader>sn",
--                     fn = function()
--                         tel.find_files({ cwd = vim.fn.stdpath("config") })
--                     end,
--                     desc = "[s]earch [n]eovim files",
--                     prefix = "TEL",
--                 })
--
--                 -- Search your notes
--                 map({
--                     mode = "n",
--                     keys = "<leader>sN",
--                     fn = function()
--                         tel.find_files({ cwd = vim.fs.abspath("~/Desktop/notes") })
--                     end,
--                     desc = "[s]earch [n]eovim files",
--                     prefix = "TEL",
--                 })
--             end,
--         },
--     },
--
--     checker = { notify = false },
--     change_detection = { notify = false },
-- })

-- =============== Treesitter ===============
-- Try to start Treesitter highlights for this buffer's filetype
-- If not parser is installed, silently fall back to :syntax enable
vim.api.nvim_create_autocmd({ "FileType" }, {
    group = aug("ts_auto_start"),
    callback = function(args)
        local ok = pcall(function() vim.treesitter.start(args.buf) end)
        if not ok then
            vim.cmd("syntax enable")
        end
    end,
})

-- =============== LSP ===============

-- Optional: default settings applied to *all* configs (wildcard "*")
-- You can keep this minimal; root_markers helps autostart at project roots.
vim.lsp.config('*', {
    root_markers = { '.git' },
})

-- ---------- Language configs ----------
-- Each config defines the executable (cmd), filetypes, and roots.
-- Add settings if your server supports them.

-- Lua (lua-language-server)
vim.lsp.config('lua_ls', {
    cmd          = { 'lua-language-server' },
    filetypes    = { 'lua' },
    root_markers = { '.luarc.json', '.luarc.jsonc', '.git' },
    settings     = {
        Lua = {
            diagnostics = { globals = { 'vim' }, disable = { 'missing-fields' } },
            completion  = { callSnippet = 'Replace' },
            format      = {
                enable = true,
                defaultConfig = {
                    indent_style = 'space',
                    indent_size = '4',
                    tab_width = '4',
                    quote_style = 'none',
                    continuation_indent = '4',
                    max_line_length = '200',
                    align_function_params = 'false',
                    align_continuous_inline_comment = 'false',
                    align_array_table = 'false',
                    break_all_list_when_line_exceed = 'false',
                    auto_collapse_lines = 'false',
                    break_before_braces = 'false',
                },
            },
        },
    },
})

-- C / C++ / ObjC (clangd)
vim.lsp.config('clangd', {
    cmd          = { 'clangd', '--background-index', '--clang-tidy' },
    filetypes    = { 'c', 'cpp', 'objc', 'objcpp', 'cuda' },
    root_markers = { 'compile_commands.json', 'compile_flags.txt', '.git' },
})

-- Go (gopls)
vim.lsp.config('gopls', {
    cmd          = { 'gopls' },
    filetypes    = { 'go', 'gomod', 'gowork' },
    root_markers = { 'go.work', 'go.mod', '.git' },
    settings     = {
        gopls = {
            usePlaceholders = true,
            analyses = { unusedparams = true, shadow = true },
            staticcheck = true,
        },
    },
})

-- Rust (rust-analyzer)
vim.lsp.config('rust_analyzer', {
    cmd          = { 'rust-analyzer' },
    filetypes    = { 'rust' },
    root_markers = { 'Cargo.toml', 'rust-project.json', '.git' },
    settings     = {
        ['rust-analyzer'] = {
            cargo = { allFeatures = true },
            check = { command = 'clippy' },
        },
    },
})

-- Zig (zls)
vim.lsp.config('zls', {
    cmd          = { 'zls' },
    filetypes    = { 'zig' },
    root_markers = { 'zls.json', '.git' },
})

-- ---------- Enable by name ----------
-- Once enabled, Neovim auto-starts the server on buffers matching filetypes
-- and rooted by root_markers/root_dir.
vim.lsp.enable({
    'lua_ls',
    'clangd',
    'gopls',
    'rust_analyzer',
    'zls',
})
-- Tip: you can enable/disable later too:
--   vim.lsp.enable('clangd', false)  -- stop/disable
--   vim.lsp.enable('clangd', true)   -- re-enable

local ok_tel, tel = pcall(require, 'telescope.builtin')
local lsp_attach_grp = aug('lsp_attach')
local lsp_detach_grp = aug('lsp_detach')

autocmd('LspAttach', {
    desc     = 'Buffer-local LSP keymaps and features',
    group    = lsp_attach_grp,
    callback = function(e)
        local bufnr  = e.buf
        local client = vim.lsp.get_client_by_id(e.data.client_id)

        -- buffer-local map wrapper using your map()
        local function bmap(table)
            table.opts = vim.tbl_extend('keep', table.opts or {}, { buffer = bufnr })
            map(table)
        end

        -- Prefer Telescope pickers if available; fall back to native functions
        local goto_def  = ok_tel and tel.lsp_definitions or vim.lsp.buf.definition
        local goto_impl = ok_tel and tel.lsp_implementations or vim.lsp.buf.implementation
        local refs      = ok_tel and tel.lsp_references or vim.lsp.buf.references
        local type_defs = ok_tel and tel.lsp_type_definitions or vim.lsp.buf.type_definition
        local doc_syms  = ok_tel and tel.lsp_document_symbols or function() vim.lsp.buf.document_symbol() end
        local ws_syms   = ok_tel and tel.lsp_dynamic_workspace_symbols or function() vim.lsp.buf.workspace_symbol('') end

        -- Navigation
        bmap({ mode = 'n', keys = 'gd', fn = goto_def, desc = '[g]oto [d]efinition', prefix = 'LSP' })
        bmap({ mode = 'n', keys = 'gD', fn = vim.lsp.buf.declaration, desc = '[g]oto [D]eclaration', prefix = 'LSP' })
        bmap({ mode = 'n', keys = 'gI', fn = goto_impl, desc = '[g]oto [I]mplementation', prefix = 'LSP' })
        bmap({ mode = 'n', keys = 'gr', fn = refs, desc = '[g]oto [r]eferences', prefix = 'LSP' })
        bmap({ mode = 'n', keys = '<leader>D', fn = type_defs, desc = 'Type [D]efinition', prefix = 'LSP' })
        bmap({ mode = 'n', keys = '<leader>ds', fn = doc_syms, desc = '[d]oc [s]ymbols', prefix = 'LSP' })
        bmap({ mode = 'n', keys = '<leader>ws', fn = ws_syms, desc = '[w]orkspace [s]ymbols', prefix = 'LSP' })

        -- Core actions
        bmap({ mode = 'n', keys = '<leader>rn', fn = vim.lsp.buf.rename, desc = '[r]e[n]ame', prefix = 'LSP' })
        bmap({
            mode = { 'n', 'x' },
            keys = '<leader>ca',
            fn = vim.lsp.buf.code_action,
            desc = '[c]ode [a]ction',
            prefix =
            'LSP'
        })
        bmap({ mode = 'n', keys = 'K', fn = vim.lsp.buf.hover, desc = 'Hover docs', prefix = 'LSP' })

        -- Inlay hints toggle (if supported)
        if client and client.supports_method(vim.lsp.protocol.Methods.textDocument_inlayHint) then
            bmap({
                mode = 'n',
                keys = '<leader>th',
                fn = function()
                    local on = vim.lsp.inlay_hint.is_enabled({ bufnr = bufnr })
                    vim.lsp.inlay_hint.enable(not on, { bufnr = bufnr })
                end,
                desc = '[t]oggle Inlay [h]ints',
                prefix = 'LSP',
            })
        end

        -- Format on save (if supported)
        if client and client.supports_method(vim.lsp.protocol.Methods.textDocument_formatting) then
            local fmtgrp = aug(('lsp_format_%d'):format(bufnr))
            autocmd('BufWritePre', {
                group = fmtgrp,
                buffer = bufnr,
                callback = function() vim.lsp.buf.format({ bufnr = bufnr, id = client.id, timeout_ms = 1500 }) end,
            })
        end

        -- Document highlight (if supported)
        if client and client.supports_method(vim.lsp.protocol.Methods.textDocument_documentHighlight) then
            local hlgrp = aug(('lsp_highlight_%d'):format(bufnr))
            autocmd({ 'CursorHold', 'CursorHoldI' }, {
                group = hlgrp, buffer = bufnr, callback = vim.lsp.buf.document_highlight,
            })
            autocmd({ 'CursorMoved', 'CursorMovedI', 'BufLeave' }, {
                group = hlgrp, buffer = bufnr, callback = vim.lsp.buf.clear_references,
            })
        end
    end,
})

autocmd('LspDetach', {
    group    = lsp_detach_grp,
    desc     = 'Clear LSP highlights on detach',
    callback = function(e)
        pcall(vim.api.nvim_del_augroup_by_name, ('1337.lsp_highlight_%d'):format(e.buf))
        pcall(vim.lsp.buf.clear_references)
    end,
})
