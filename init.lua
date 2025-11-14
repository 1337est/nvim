local utils = require("utils")
local augroup = utils.augroup
local autocmd = utils.autocmd
local map = utils.map

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

-- Window split behavior
vim.opt.splitright = true -- new splits open right
vim.opt.splitbelow = true -- new splits open below
-- Floating windows
vim.opt.winblend = 10

-- Gutter
vim.opt.number = true -- Make line numbers default
vim.opt.relativenumber = true -- Shows line # away from current line #
vim.opt.signcolumn = "yes" -- Show sign column
vim.opt.foldcolumn = "1"
vim.opt.foldmethod = "indent"
-- vim.opt.foldexpr = "nvim_treesitter#foldexpr()"
vim.opt.foldlevel = 99

-- Indicator / hl-lines
vim.opt.cursorline = true -- Show which line your cursor is on
vim.opt.colorcolumn = "100" -- Line at the nth column

-- gui styles
vim.opt.termguicolors = true -- Enables 24-bit RGB color
vim.opt.guicursor = "" -- Disable cursor styling

-- screen rendering
vim.opt.lazyredraw = true

-- Mouse support
vim.opt.mouse = "a" -- Enables mouse mode
vim.opt.mousescroll = "ver:1,hor:1"

-- automatic behavior
vim.opt.autoread = true
vim.opt.autowrite = false
vim.opt.autochdir = false
vim.opt.confirm = true

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
vim.opt.listchars = { tab = "<->", trail = ".", nbsp = "-", }

-- Sync clipboard between OS and Neovim.
--  Remove this option if you want your OS clipboard to remain independent.
--  See `:help 'clipboard'`
vim.schedule(function() vim.opt.clipboard = "unnamedplus" end)

-- Completions Ctrl-x-Ctrl-o
vim.opt.updatetime = 250 -- Time after CursorHold Event (faster completions)
vim.opt.timeoutlen = 300 -- Mapped key sequence wait time
vim.opt.completeopt = "menuone,noinsert,noselect"
vim.opt.pumheight = 10
vim.opt.pumblend = 10

-- Viewdir/folds
vim.opt.viewdir = vim.fn.stdpath("state") .. "/viewdir//"
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

-- =============== General Autocmds & Augroups ===============

autocmd({
    event    = "TextYankPost",
    owner    = "1337",
    group    = "hl_on_yank",
    desc     = "Brief highlight on yank",
    patbuf  = "*",
    callback = function()
        vim.hl.on_yank({ higroup = "IncSearch", timeout = 40 })
    end,
})

autocmd({
    event    = "BufEnter",
    owner    = "1337",
    group    = "format_opts_remove_cro",
    desc     = "Removes automatic continuation comments when entering a buffer",
    patbuf  = "*",
    fncmd = function()
        vim.opt.formatoptions:remove({ "c", "r", "o" })
    end,
})

autocmd({
    event   = "BufWinLeave",
    owner   = "1337",
    desc    = "Remembers folds on window leave",
    group   = "fold_remember_on_leave",
    patbuf = "*.*",
    command = "mkview",
})

autocmd({
    event   = "BufWinEnter",
    owner   = "1337",
    group   = "fold_remember_on_enter",
    desc    = "Remembers folds on window enter",
    patbuf = "*.*",
    command = "silent! loadview",
})

autocmd({
    event    = "BufEnter",
    owner    = "1337",
    group    = "textfile_wrap_and_spell_on",
    desc     = "Turns on text wrap + spell for text-ish files",
    patbuf  = { "*.md", "*.txt", "*.norg" },
    fncmd = function()
        vim.opt_local.wrap  = true
        vim.opt_local.spell = true
    end,
})

autocmd({
    event    = "FileType",
    owner    = "1337",
    group    = "ts_auto_start",
    desc     = "Automatically starts treesitter with syntax enable fallback",
    patbuf  = "*",
    fncmd = function(args)
        local ok = pcall(function() vim.treesitter.start(args.buf) end)
        if not ok then vim.cmd("syntax enable") end
    end,
})

-- =============== Plugins (Custom Autocmds, Augroups, Maps) ===============

-- TODO: Add require's pack/plugins/start/plugin/ for others not listed here.
require("colorizer").setup()
require("ibl").setup()
require("lualine").setup {}
require("barbar").setup {}
require("telescope").setup {
    extensions = { ["ui-select"] = { require("telescope.themes").get_dropdown() }, },
    pickers = { find_files = { hidden = true, no_ignore = true, no_ignore_parent = true, }, },
    defaults = { file_ignore_patterns = { "undodir", "node_modules", }, },
}

-- keymaps: '<leader>' + key ->  Regular extensions

-- START: Make sure all these names match and are right
map({
    mode = "n",
    keys = "<leader><Esc>",
    owner = "1337",
    desc = "Clear search hl",
    fn = "<cmd>nohlsearch<CR>"
})

map({
    mode = "v",
    keys = "<leader>p",
    owner = "1337",
    desc = "[p]aste",
    fn = [["_dP]]
})

map({
    mode = { "n", "v" },
    keys = "<leader>d",
    owner = "1337",
    desc = "[d]elete",
    fn = [["_d]]
})

-- keymaps: ']' + key -> Next extensions
map({
    mode = "n",
    keys = "]d",
    owner = "1337",
    desc = "Next [d]iagnostic",
    fn = vim.diagnostic.goto_next
})

-- keymaps: '[' + key -> Previous extensions
map({
    mode = "n",
    keys = "[d",
    owner = "1337",
    desc = "Previous [d]iagnostic",
    fn = vim.diagnostic.goto_prev
})

local ok_tel, tel = pcall(require, 'telescope.builtin')
-- keymaps: '<leader>s' -> Search extensions
map({
    mode = "n",
    keys = "<leader>snh",
    owner = "TEL",
    desc = "[s]earch nvim [h]elp_tags",
    fn = tel.help_tags
})

map({
    mode = "n",
    keys = "<leader>snm",
    owner = "TEL",
    desc = "[s]earch nvim key[m]aps",
    fn = tel.keymaps
})

map({
    mode = "n",
    keys = "<leader>stb",
    owner = "TEL",
    desc = "[s]earch [t]el [b]uiltins",
    fn = tel.builtin
})

map({
    mode = "n",
    keys = "<leader>sfn",
    owner = "TEL",
    desc = "[s]earch [f]ile [n]ames",
    fn = tel.find_files
})

map({
    mode = "n",
    keys = "<leader>swh",
    owner = "TEL",
    desc = "[s]earch [w]ord [c]ursor",
    fn = tel.grep_string
})

map({
    mode = "n",
    keys = "<leader>swg",
    owner = "TEL",
    desc = "[s]earch [w]ord [g]rep",
    fn = tel.live_grep
})

map({
    mode = "n",
    keys = "<leader>sd",
    owner = "TEL",
    desc = "[s]earch [d]iagnostics",
    fn = tel.diagnostics
})

-- LLO: should be ctrl-o <leader>t + ctrl-o
map({
    mode = "n",
    keys = "<leader>sr",
    owner = "TEL",
    desc = "[s]earch [r]esume",
    fn = tel.resume
})

map({
    mode = "n",
    keys = "<leader>s.",
    owner = "TEL",
    desc = "[s]earch Recent Files ('.' for repeat)",
    fn = tel.oldfiles
})

map({
    mode = "n",
    keys = "<leader><leader>",
    owner = "TEL",
    desc = "[ ] Find existing buffers",
    fn = tel.buffers
})

map({
    mode = "n",
    keys = "<leader>/",
    owner = "TEL",
    desc = "[/] Fuzzily search in current buffer",
    fn = function() tel.current_buffer_fuzzy_find(require("telescope.themes").get_dropdown({ winblend = 10, previewer = false, })) end,
})

map({
    mode = "n",
    keys = "<leader>s/",
    owner = "TEL",
    desc = "[s]earch [/] in Open Files",
    fn = function() tel.live_grep({ grep_open_files = true, prompt_title = "Live Grep in Open Files", }) end,
})

-- Search your Neovim config
map({
    mode = "n",
    keys = "<leader>sn",
    owner = "TEL",
    desc = "[s]earch [n]eovim files",
    fn = function() tel.find_files({ cwd = vim.fn.stdpath("config") }) end,
})

-- END: Ending block for Start todo
-- =============== LSP ===============

-- Optional: default settings applied to *all* configs (wildcard "*")
-- You can keep this minimal; root_markers helps autostart at project roots.
vim.lsp.config('*', { root_markers = { '.git' }, })

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
        ['rust-analyzer'] = { cargo = { allFeatures = true }, check = { command = 'clippy' }, },
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

local lsp_owner = "LSP"
local lsp_attach_grp = augroup(lsp_owner, 'attach')
local lsp_detach_grp = augroup(lsp_owner, 'detach')

autocmd({
    event    = "LspAttach",
    owner    = lsp_owner,
    group    = lsp_attach_grp,
    desc     = 'Buffer-local LSP keymaps and features',
    patbuf  = "*",
    fncmd = function(e)
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
        bmap({
            mode = 'n',
            keys = 'grr',
            owner = lsp_owner,
            desc = '[g]oto [r]eferences',
            fn = refs
        })
        bmap({
            mode = 'n',
            keys = 'gri',
            owner = lsp_owner,
            desc = '[g]oto [I]mplementation',
            fn = goto_impl
        })
        bmap({
            mode = 'n',
            keys = 'grn',
            owner = lsp_owner,
            desc = '[r]e[n]ame',
            fn = vim.lsp.buf.rename
        })
        bmap({
            mode = 'n',
            keys = 'grt',
            owner = lsp_owner,
            desc = 'Type [D]efinition',
            fn = type_defs
        })
        bmap({
            mode = { 'n', 'x' },
            keys = 'gra',
            owner = lsp_owner,
            desc = '[c]ode [a]ction',
            fn = vim.lsp.buf.code_action
        })
        bmap({
            mode = 'n',
            keys = 'gd',
            owner = lsp_owner,
            desc = '[g]oto [d]efinition',
            fn = goto_def
        })
        bmap({
            mode = 'n',
            keys = 'gD',
            owner = lsp_owner,
            desc = '[g]oto [D]eclaration',
            fn = vim.lsp.buf.declaration
        })
        bmap({
            mode = 'n',
            keys = '<leader>ds',
            owner = lsp_owner,
            desc = '[d]oc [s]ymbols',
            fn = doc_syms
        })
        bmap({
            mode = 'n',
            keys = '<leader>ws',
            owner = lsp_owner,
            desc = '[w]orkspace [s]ymbols',
            fn = ws_syms
        })
        bmap({
            mode = 'n',
            keys = 'K',
            owner = lsp_owner,
            desc = 'Hover docs',
            fn = vim.lsp.buf.hover
        })

        if client and client.supports_method(vim.lsp.protocol.Methods.textDocument_inlayHint) then
            bmap({
                mode = 'n',
                keys = '<leader>th',
                owner = lsp_owner,
                desc = '[t]oggle Inlay [h]ints',
                fn = function()
                    local on = vim.lsp.inlay_hint.is_enabled({ bufnr = bufnr })
                    vim.lsp.inlay_hint.enable(not on, { bufnr = bufnr })
                end,
            })
        end

        if client and client.supports_method(vim.lsp.protocol.Methods.textDocument_formatting) then
            local lsp_fmt_grp = augroup(lsp_owner, ('format_%d'):format(bufnr))
            autocmd({
                event = "BufWritePre",
                owner = lsp_owner,
                group = lsp_fmt_grp,
                desc = "Format on save",
                buffer = bufnr,
                fncmd = function() vim.lsp.buf.format({ bufnr = bufnr, id = client.id, timeout_ms = 1500 }) end,
            })
        end

        -- Document highlight (if supported)
        if client and client.supports_method(vim.lsp.protocol.Methods.textDocument_documentHighlight) then
            local lsp_hl_grp = augroup(lsp_owner, ('highlight_%d'):format(bufnr))
            autocmd({
                event = { 'CursorHold', 'CursorHoldI' },
                owner = lsp_owner,
                group = lsp_hl_grp,
                desc = "LSP document highlight",
                buffer = bufnr,
                fncmd = vim.lsp.buf.document_highlight,
            })
            autocmd({
                event = { 'CursorMoved', 'CursorMovedI', 'BufLeave' },
                owner = lsp_owner,
                group = lsp_hl_grp,
                desc = "Clear LSP references",
                buffer = bufnr,
                fncmd = vim.lsp.buf.clear_references,
            })
        end
    end,
})

autocmd({
    event    = 'LspDetach',
    owner    = lsp_owner,
    group    = lsp_detach_grp,
    desc     = 'Clear LSP highlights on detach',
    patbuf  = "*",
    fncmd = function(e)
        pcall(vim.api.nvim_del_augroup_by_name, ('LSP.highlight_%d'):format(e.buf))
        pcall(vim.lsp.buf.clear_references)
    end,
})

-- HACK: Mostly generated by ChatGPT, need to go through and fix. A little buggy,
-- but gets the job done.
--------------------------------------------------------------------------------
-- Comment tag highlights (plugin-free, token-only) + Tree-sitter incremental
-- - Highlights ONLY the tag tokens (e.g. "TODO: ") when inside comments
-- - Uses TS on_changedtree for near-keystroke updates when available
-- - Falls back to simple autocmd-based refresh when no TS parser exists
--------------------------------------------------------------------------------

local ns = vim.api.nvim_create_namespace("1337.comment_tags")
local TAGS = {
    {
        hl = "1337TagTODO",
        words = {
            "TODO:", -- TODO: Leave a comment for something you need to get done.
            "LLO:", -- LLO: last left off.
            "START:", -- START: starts/go here first
            "END:", -- END: ends/go here last
            "HERE:", -- HERE: go here
        }
    },
    {
        hl = "1337TagTEST",
        words = {
            " TEST:", -- TEST: testing or test
            " EXP:", -- EXP: experimental block
            " TEMP:", -- TEMP: this is temporary
        }
    },
    {
        hl = "1337TagPASS",
        words = {
            " PASS:", -- PASS: passing test
        }
    },
    {
        hl = "1337TagPERF",
        words = {
            " PERF:", -- PERF: performance block
            " OPTIM:", -- OPTIM: optimized/optimal/ or optimization block
        }
    },
    {
        hl = "1337TagFAIL",
        words = {
            " FAIL:", -- FAIL: Failed block
            " ERROR:", -- ERROR: This probably breaks things
            " FIXME:", -- FIXME: please?
            " BUG:", -- BUG: Eww, squish it!
        }
    },
    {
        hl = "1337TagWARN",
        words = {
            " WARNING:", -- WARNING: You have been warned...
            " HACK: ", -- HACK: This was hacked up!
            " CAUTION: ", -- CAUTION: Proceed with caution, ok?
        }
    },
    {
        hl = "1337TagNOTE",
        words = {
            " NOTE: ", -- NOTE: Small note info.
            " INFO: ", -- INFO: General info.
            " NEW: ", -- NEW: New info.
            " OLD: ", -- OLD: old info.
        }
    },
}

-- Is (row,col) inside a comment? Prefer Tree-sitter; fall back to :syntax
local function in_comment(buf, row, col)
    if vim.treesitter and vim.treesitter.get_captures_at_pos then
        local ok, caps = pcall(vim.treesitter.get_captures_at_pos, buf, row, col)
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

-- Range-based scan & highlight (clears + repaints only the range)
local function refresh_range(buf, srow, erow)
    buf = buf or 0
    if not vim.api.nvim_buf_is_loaded(buf) then return end

    local last = math.max(0, vim.api.nvim_buf_line_count(buf) - 1)
    srow = math.max(0, tonumber(srow) or 0)
    erow = (erow == nil or erow < 0) and last or math.min(tonumber(erow) or last, last)

    vim.api.nvim_buf_clear_namespace(buf, ns, srow, erow + 1)
    local lines = vim.api.nvim_buf_get_lines(buf, srow, erow + 1, false)

    for i, line in ipairs(lines) do
        local row = srow + i - 1
        for _, tag in ipairs(TAGS) do
            for _, word in ipairs(tag.words) do
                local init = 1
                while true do
                    local s, e = string.find(line, word, init, true) -- plain search
                    if not s then break end
                    local col0 = s - 1
                    if in_comment(buf, row, col0) then
                        vim.api.nvim_buf_add_highlight(buf, ns, tag.hl, row, col0, col0 + #word)
                    end
                    init = e + 1
                end
            end
        end
    end
end

-- Full-buffer repaint helper
local function refresh(buf)
    buf = buf or 0
    refresh_range(buf, 0, -1)
end

-- Tree-sitter incremental updates (robust across change shapes)
local UINT_MAX = 0xFFFFFFFF
local function handle_ts_changes(buf, changes)
    local minr, maxr = math.huge, -1
    local lastrow    = math.max(0, vim.api.nvim_buf_line_count(buf) - 1)

    for _, ch in ipairs(changes or {}) do
        local sr, er
        if type(ch[1]) == "table" and type(ch[2]) == "table" then
            -- { {sr,sc,sb}, {er,ec,eb} }
            sr = ch[1][1] or 0
            er = ch[2][1] or sr
        else
            -- { sr, sc, [sb], er, ec, [eb] }  (sometimes 4 ints, sometimes 6)
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
        refresh_range(buf, 0, -1)
    else
        refresh_range(buf, minr, maxr)
    end
end

local function attach_ts(buf)
    -- Start TS highlighter so on_changedtree fires during edits
    pcall(vim.treesitter.start, buf)
    -- Initial paint
    refresh_range(buf, 0, -1)

    local ok, parser = pcall(vim.treesitter.get_parser, buf)
    if not ok or not parser then return end

    parser:register_cbs({
        on_changedtree = function(changes, _)
            vim.schedule(function()
                if vim.api.nvim_buf_is_valid(buf) then
                    handle_ts_changes(buf, changes)
                end
            end)
        end,
    })
end

-- Manual command
vim.api.nvim_create_user_command("CommentTagsRefresh", function()
    refresh(0)
end, { desc = "Refresh comment tag highlights (token-only)" })

-- TODO: Attach TS when possible; else fall back to simple autocmd refresh
local grp_ts = augroup("TS", "comment_tags_ts")
autocmd({
    event = { "BufEnter", "FileType" },
    owner = "TS",
    group = grp_ts,
    desc = "Attach TreeSitter-based comment tags if parser is available",
    patbuf = "*",
    fncmd = function(args)
        if vim.b[args.buf].comment_tags_ts_attached then return end
        local ok = pcall(vim.treesitter.get_parser, args.buf)
        if not ok then return end
        vim.b[args.buf].comment_tags_ts_attached = true
        attach_ts(args.buf)
    end,
})

local grp_fb = augroup("1337", "comment_tags_fallback")
autocmd({
    event = { "BufEnter", "TextChanged", "InsertLeave", "BufWritePost" },
    owner = "1337",
    group = grp_fb,
    desc = "Fallback refresh of comment tags when TreeSitter is not attached",
    patbuf = "*",
    fncmd = function(args)
        if vim.b[args.buf].comment_tags_ts_attached then return end -- TS will handle it
        refresh(args.buf)
    end
})

-- Reapply groups & repaint on colorscheme reload
autocmd({
    event = "ColorScheme",
    owner = "1337",
    group = grp_fb,
    desc = "Reapply comment tags on colorscheme reload",
    patbuf = "*",
    fncmd = function()
        if vim.api.nvim_buf_is_valid(0) then refresh(0) end
    end,
})

-- Initial apply for current buffer
refresh(0)
