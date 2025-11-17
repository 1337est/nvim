local utils = require("utils")
local augroup = utils.augroup
local autocmd = utils.autocmd
local map = utils.map

-----------------------------------------------------------------------------------
-- AESTHETICS: HIGHLIGHTS / TREESITTER / COLORSCHEME / GUTTER / VIEW / CONCEAL / TEXT / WHITESPACE
-----------------------------------------------------------------------------------
-- colors/1337dark.lua
vim.cmd.colorscheme("1337dark") -- check out colors/1337dark.lua

-- globals
vim.g.mapleader        = " " -- Sets space as the leader key
vim.g.maplocalleader   = " " -- Sets space as the leader key
vim.g.have_nerd_font   = true -- For my nerd font

-- gutter
vim.opt.number         = true -- Make line numbers default
vim.opt.relativenumber = true -- Shows line # away from current line #
vim.opt.signcolumn     = "yes" -- Show sign column
vim.opt.foldcolumn     = "1"
vim.opt.foldmethod     = "indent"
-- vim.opt.foldexpr = "nvim_treesitter#foldexpr()"
vim.opt.foldlevel      = 99

-- row/column indicators
vim.opt.cursorline     = true -- Show which line your cursor is on
vim.opt.colorcolumn    = "100" -- Line at the nth column

-- gui
vim.opt.termguicolors  = true -- Enables 24-bit RGB color
vim.opt.guicursor      = "" -- Disable cursor styling

-- render
vim.opt.lazyredraw     = true

-- whitespace
vim.opt.expandtab      = true -- Use appropriate spaces to insert tabs
vim.opt.shiftwidth     = 4 -- 4 spaces for (auto)indenting
vim.opt.tabstop        = 4 -- tabs are 4 spaces
vim.opt.smartindent    = true -- Smart auto-indenting on new lines

-- conceal
vim.opt.conceallevel   = 0
vim.opt.concealcursor  = ""
vim.opt.list           = true
vim.opt.listchars      = { tab = "<->", trail = ".", nbsp = "-", }

-- statusline / windows / tabs
vim.opt.showmode       = false -- Don't show mode, since it's already in status line
vim.opt.laststatus     = 3
vim.opt.showtabline    = 2
vim.opt.ruler          = true
local MODES            = {
    {
        hl = "User1",
        normal = {
            n         = "[N]", -- normal
            no        = "[NP]", -- operator-pending
            nov       = "[NP-V]", -- forced charwise
            noV       = "[NP-VL]", -- forced linewise
            ["no\22"] = "[NP-VB]", -- forced blockwise
            nt        = "[NT]", -- normal terminal
            -- Normal via i_CTRL-O / terminal variants
            niI       = "[N->I]", -- normal back to insert
            niR       = "[N->R]", -- normal back to replace
            niV       = "[N->Rv]", -- normal back to virtual replace
            ntT       = "[NT->T]", -- normal terminal back to Terminal
        },
    },
    {
        hl = "User2",
        visual = {
            -- Visual / Select-mode via v_CTRL-O
            v        = "[V]", -- visual mode
            vs       = "[V-S]", -- visual select
            V        = "[VL]", -- Visual line
            Vs       = "[VL-S]", -- visual select
            ["\22"]  = "[VB]", -- Visual block
            ["\22s"] = "[VB-S]", -- Visual block select
        },
    },
    {
        hl = "User3",
        select = {
            -- Select modes (char/line/block)
            s       = "[S]", -- select
            S       = "[SL]", -- select line
            ["\19"] = "[SB]", -- Select block <Ctrl-S>
        },
    },
    {
        hl = "User4",
        insert = {
            -- Insert + completions variants
            i  = "[I]", -- insert
            ic = "[I-c]", -- insert completion generic
            ix = "[I-cx]", -- insert completion via Ctrl-x
        },
    },
    {
        hl = "User5",
        replace = {
            -- Replace / Virtual-Replace + completion variants
            R   = "[R]", -- replace
            Rc  = "[R-c]", -- replace completion generic
            Rx  = "[R-cx]", -- replace completion via Ctrl-x
            Rv  = "[Rv]", -- virtual replace
            Rvc = "[Rv-c]", -- virtual replace completion generic
            Rvx = "[Rv-cx]", -- virtual replace completion via Ctrl-x
        },
    },
    {
        hl = "User6",
        command = {
            -- Command-line editing variants
            c   = "[C]", -- command
            cr  = "[C-r]", -- command replace
            cv  = "[Ex]", -- command Ex
            cvr = "[Ex-r]", -- command Ex replace
        },
    },
    {
        hl = "User7",
        -- Prompts / external / terminal
        terminal = {
            t = "[T]", -- terminal
        },
    },
    {
        hl = "User1",
        extra = {
            r      = "[Hit]", -- hit enter prompt
            rm     = "[More]", -- -- more-- prompt
            ["r?"] = "[Conf]", -- :confirm query of some sort
            ["!"]  = "[!]", -- Shell or external command is executing
        },
    },
}

-- build mode segment using MODES + User1..User7 hl groups
function _G.StatuslineMode()
    -- non-0 arg gets extendded mode string for extra info
    local cur_mode = vim.fn.mode(1)

    for _, entry in ipairs(MODES) do
        local hl = entry.hl or "User1"

        -- each entry has exactly one of: normal/visual/select/...
        for key, mode_map in pairs(entry) do
            if key ~= "hl" and type(mode_map) == "table" then
                local label = mode_map[cur_mode]
                if label then
                    -- If hl is "UserN", prefer %N* syntax; otherwise use %#Group#
                    local idx = hl:match("^User(%d+)$")
                    if idx then
                        -- -> %1* [N]%*  (highlights with User1)
                        return string.format("%%%s* %s %%* ", idx, label)
                    else
                        -- Fallback: explicit highlight group name
                        return string.format("%%#%s# %s %%* ", hl, label)
                    end
                end
            end
        end
    end

    -- Fallback if we somehow don't know the mode
    return " [?] "
end

vim.o.statusline = "%{%v:lua.StatuslineMode()%}%y %<%f%=%l,%c %3p%%"
vim.o.winbar = "%F"

autocmd({
    event  = "FileType",
    owner  = "1337",
    group  = "ts_auto_start",
    desc   = "Automatically starts treesitter with syntax enable fallback",
    patbuf = "*",
    fncmd  = function(args)
        local ok = pcall(function() vim.treesitter.start(args.buf) end)
        if not ok then vim.cmd("syntax enable") end
    end,
})

-----------------------------------------------------------------------------------
-- BEHAVIOR: BUFFERS / VIEWPORTS / RENDERING / WRITING / READING / WINDOWS / TABS / FLOATS / POPUPS
-----------------------------------------------------------------------------------
vim.opt.autoread = true
vim.opt.autowrite = false
vim.opt.autochdir = false
vim.opt.confirm = true

vim.opt.splitright = true -- new splits open right
vim.opt.splitbelow = true -- new splits open below
vim.opt.winblend = 10

vim.opt.wrap = false -- Don't wrap text
vim.opt.spell = false
vim.opt.linebreak = true -- Wraps words instead of characters
vim.opt.scrolloff = 1 -- Minimal screen lines above/below the cursor
vim.opt.sidescrolloff = 1 -- Minimal screen lines to keep left/right
autocmd({
    event  = "BufEnter",
    owner  = "1337",
    group  = "textfile_wrap_and_spell_on",
    desc   = "Turns on text wrap + spell for text-ish files",
    patbuf = { "*.md", "*.txt", "*.norg" },
    fncmd  = function()
        vim.opt_local.wrap  = true
        vim.opt_local.spell = true
    end,
})

-- view state
vim.opt.viewdir = vim.fn.stdpath("state") .. "/viewdir//"
autocmd({
    event  = "BufWinLeave",
    owner  = "1337",
    desc   = "Remembers folds on window leave",
    group  = "fold_remember_on_leave",
    patbuf = "*.*",
    fncmd  = "mkview",
})
autocmd({
    event  = "BufWinEnter",
    owner  = "1337",
    group  = "fold_remember_on_enter",
    desc   = "Remembers folds on window enter",
    patbuf = "*.*",
    fncmd  = "silent! loadview",
})

-- undo state
vim.opt.undodir = vim.fn.stdpath("state") .. "/undodir//"
vim.opt.undofile = true -- Save undo history

-- backup state
vim.opt.backup = false
vim.opt.writebackup = false

-- swap state
vim.opt.swapfile = false

----------------------------------------------------------------------------------------------
-- ACTIONS: FINDING / SEARCHING / NAVIGATION / EXPLORER / MARKS / JUMPS / COMPLETIONS / MOVES
----------------------------------------------------------------------------------------------
-- Sync clipboard between OS and Neovim.
--  Remove this option if you want your OS clipboard to remain independent.
--  See `:help 'clipboard'`
vim.schedule(function() vim.opt.clipboard = "unnamedplus" end)
autocmd({
    event = "TextYankPost",
    owner = "1337",
    group = "hl_on_yank",
    desc = "Brief highlight on yank",
    patbuf = "*",
    fncmd = function()
        vim.hl.on_yank({ higroup = "IncSearch", timeout = 40 })
    end,
})
map({ mode = "x", keys = "<leader>p", owner = "1337", desc = "paste over without yanking", fn = [["_dP]] })
map({ mode = { "n", "v" }, keys = "<leader>d", owner = "1337", desc = "delete without yanking", fn = [["_d]] })

-- searching
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.incsearch = true -- Shows pattern match as you type
vim.opt.inccommand = "split" -- preview substitutions live as you type
vim.opt.hlsearch = true -- Set highlight on search
vim.opt.iskeyword:append("-")
map({ mode = "n", keys = "n", owner = "1337", desc = "next search centered", fn = "nzz" })
map({ mode = "n", keys = "N", owner = "1337", desc = "previoius search centered", fn = "Nzz" })
map({ mode = "n", keys = "<C-u>", owner = "1337", desc = "Half page up centered", fn = "<C-u>zz" })
map({ mode = "n", keys = "<C-d>", owner = "1337", desc = "Half page down centered", fn = "<C-d>zz" })
map({ mode = "n", keys = "<C-f>", owner = "1337", desc = "Full page up centered", fn = "<C-f>zz" })
map({ mode = "n", keys = "<C-b>", owner = "1337", desc = "Full page down centered", fn = "<C-b>zz" })
map({ mode = "n", keys = "J", owner = "1337", desc = "Join lines, keep cursor position", fn = "mzJ`z" })

-- Moving blocks of text with active selection
map({ mode = "n", keys = "<A-j>", owner = "1337", desc = "Move line down", fn = ":m .+1<CR>==" })
map({ mode = "n", keys = "<A-k>", owner = "1337", desc = "Move line up", fn = ":m .-2<CR>==" })
map({ mode = "v", keys = "<A-j>", owner = "1337", desc = "Move selection down", fn = ":m '>+1<CR>gv=gv" })
map({ mode = "v", keys = "<A-k>", owner = "1337", desc = "Move selection up", fn = ":m '<-2<CR>gv=gv" })
map({ mode = "v", keys = "<A-.>", owner = "1337", desc = "Indent right reselect", fn = ">gv" })
map({ mode = "v", keys = "<A-,>", owner = "1337", desc = "Indent left reselect", fn = "<gv" })

-- File Explorering
map({ mode = "n", keys = "<leader>e", owner = "1337", desc = "Explorer", fn = ":Explore<CR>" })

-- reloading config
map({ mode = "n", keys = "<leader>r", owner = "1337", desc = "write and reload file", fn = ":w<CR>:so<CR>" })

-- mouse
vim.opt.mouse = "a" -- Enables mouse mode
vim.opt.mousescroll = "ver:1,hor:1"

-- completions
vim.opt.updatetime = 250 -- Time after CursorHold Event (faster completions)
vim.opt.timeoutlen = 300 -- Mapped key sequence wait time
vim.opt.completeopt = "menuone,noinsert,noselect"
vim.opt.pumheight = 10
vim.opt.pumblend = 10

-- formatting
autocmd({
    event  = "BufEnter",
    owner  = "1337",
    group  = "format_opts_remove_cro",
    desc   = "Removes automatic continuation comments when entering a buffer",
    patbuf = "*",
    fncmd  = function()
        vim.opt.formatoptions:remove({ "c", "r", "o" })
    end,
})

------------------------------------------------------------------------------------------------------

-- =============== Plugins (Custom Autocmds, Augroups, Maps) ===============

-- =========================== Search Telescope / Functions / Maps ============================
require("telescope").setup {
    extensions = { ["ui-select"] = { require("telescope.themes").get_dropdown() }, },
    pickers = { find_files = { hidden = true, no_ignore = true, no_ignore_parent = true, }, },
    defaults = { file_ignore_patterns = { "undodir", "node_modules", }, },
}
local ok_tel, tel = pcall(require, 'telescope.builtin')

map({ mode = "n", keys = "<leader>st", owner = "TEL", desc = "telescope builtins", fn = tel.builtin })

map({ mode = "n", keys = "<leader>sk", owner = "TEL", desc = "search nvim keymaps", fn = tel.keymaps })
map({ mode = "n", keys = "<leader>sh", owner = "TEL", desc = "search nvim help_tags", fn = tel.help_tags })

map({ mode = "n", keys = "<leader>sf", owner = "TEL", desc = "search file by name from cwd", fn = tel.find_files })
map({ mode = "n", keys = "<leader>so", owner = "TEL", desc = "search file by name from file history", fn = tel.oldfiles })
map({ mode = "n", keys = "<leader>sb", owner = "TEL", desc = "Find existing buffers", fn = tel.buffers })

map({ mode = "n", keys = "<leader>s/", owner = "TEL", desc = "search word with dynamic grep", fn = tel.live_grep })

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
local m = vim.lsp.protocol.Methods

autocmd({
    event  = "LspAttach",
    owner  = lsp_owner,
    group  = lsp_attach_grp,
    desc   = 'Buffer-local LSP keymaps and features',
    patbuf = "*",
    fncmd  = function(e)
        local bufnr  = e.buf
        local client = vim.lsp.get_client_by_id(e.data.client_id)

        -- buffer-local map wrapper using your map()
        local function bmap(table)
            table.opts = vim.tbl_extend('keep', table.opts or {}, { buffer = bufnr })
            map(table)
        end

        bmap({ mode = { 'n', 'x' }, keys = 'gra', owner = lsp_owner, desc = 'code action', fn = vim.lsp.buf.code_action })
        bmap({ mode = 'n', keys = 'gri', owner = lsp_owner, desc = 'goto Implementation', fn = vim.lsp.buf.implementation })
        bmap({ mode = 'n', keys = 'grn', owner = lsp_owner, desc = 'rename', fn = vim.lsp.buf.rename })
        bmap({ mode = 'n', keys = 'grr', owner = lsp_owner, desc = 'goto references', fn = vim.lsp.buf.references })
        bmap({ mode = 'n', keys = 'grt', owner = lsp_owner, desc = 'Type Definition', fn = vim.lsp.buf.type_definition })
        bmap({ mode = 'n', keys = 'grd', owner = lsp_owner, desc = 'goto definition', fn = vim.lsp.buf.definition })
        bmap({ mode = 'n', keys = 'grD', owner = lsp_owner, desc = 'goto Declaration', fn = vim.lsp.buf.declaration })
        bmap({ mode = 'n', keys = 'gO', owner = lsp_owner, desc = 'doc symbols', fn = vim.lsp.buf.document_symbol })
        bmap({ mode = 'n', keys = 'gW', owner = lsp_owner, desc = 'workspace symbols', fn = vim.lsp.buf.workspace_symbol })
        bmap({ mode = 'n', keys = 'K', owner = lsp_owner, desc = 'Hover docs', fn = vim.lsp.buf.hover })
        if client and client.supports_method(m.textDocument_inlayHint) then
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

        if client and client.supports_method(m.textDocument_formatting) then
            local lsp_fmt_grp = augroup(lsp_owner, ('format_%d'):format(bufnr))
            autocmd({
                event = "BufWritePre",
                owner = lsp_owner,
                group = lsp_fmt_grp,
                desc = "Format on save",
                patbuf = bufnr,
                fncmd = function() vim.lsp.buf.format({ bufnr = bufnr, id = client.id, timeout_ms = 1500 }) end,
            })
        end

        -- Document highlight (if supported)
        if client and client.supports_method(m.textDocument_documentHighlight) then
            local lsp_hl_grp = augroup(lsp_owner, ('highlight_%d'):format(bufnr))
            autocmd({
                event = { 'CursorHold', 'CursorHoldI' },
                owner = lsp_owner,
                group = lsp_hl_grp,
                desc = "LSP document highlight",
                patbuf = bufnr,
                fncmd = vim.lsp.buf.document_highlight,
            })
            autocmd({
                event = { 'CursorMoved', 'CursorMovedI' },
                owner = lsp_owner,
                group = lsp_hl_grp,
                desc = "Clear LSP references",
                patbuf = bufnr,
                fncmd = vim.lsp.buf.clear_references,
            })
            autocmd({
                event  = 'LspDetach',
                owner  = lsp_owner,
                group  = lsp_detach_grp,
                desc   = 'Clear LSP highlights on detach',
                patbuf = "*",
                fncmd  = function(e)
                    pcall(vim.api.nvim_del_augroup_by_name, ('LSP.highlight_%d'):format(e.buf))
                    pcall(vim.lsp.buf.clear_references)
                end,
            })
        end
    end,
})

-- ======================= DIAGNOSTICS ====================================================
vim.diagnostic.config = {
    severity_sort = true,
    float = { border = 'rounded', source = 'if_many' },
    underline = { severity = vim.diagnostic.severity.ERROR },
    signs = vim.g.have_nerd_font and {
        text = {
            [vim.diagnostic.severity.ERROR] = '󰅚 ',
            [vim.diagnostic.severity.WARN] = '󰀪 ',
            [vim.diagnostic.severity.INFO] = '󰋽 ',
            [vim.diagnostic.severity.HINT] = '󰌶 ',
        },
    } or {},
    virtual_text = {
        source = 'if_many',
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
}
map({ mode = "n", keys = "<leader>sd", owner = "TEL", desc = "search diagnostics list", fn = tel.diagnostics })

-- HACK: Mostly generated by ChatGPT, need to go through and fix. A little buggy,
-- but gets the job done.
--------------------------------------------------------------------------------
-- Comment tag highlights (plugin-free, token-only) + Tree-sitter incremental
-- - Highlights ONLY the tag tokens (e.g." TODO:") when inside comments
-- - Uses TS on_changedtree for near-keystroke updates when available
-- - Falls back to simple autocmd-based refresh when no TS parser exists
--------------------------------------------------------------------------------

local ns = vim.api.nvim_create_namespace("1337.comment_tags")
local TAGS = {
    {
        hl = "1337TagTODO",
        words = {
            " TODO:", -- TODO: Leave a comment for something you need to get done.
            " LLO:", -- LLO: last left off.
            " START:", -- START: starts/go here first
            " END:", -- END: ends/go here last
            " HERE:", -- HERE: go here
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
            " HACK:", -- HACK: This was hacked up!
            " CAUTION:", -- CAUTION: Proceed with caution, ok?
        }
    },
    {
        hl = "1337TagNOTE",
        words = {
            " NOTE:", -- NOTE: Small note info.
            " INFO:", -- INFO: General info.
            " NEW:", -- NEW: New info.
            " OLD:", -- OLD: old info.
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

-- Hex color highlighter: "#RRGGBB" -> colored bg, easy to see fg
local function highlight_hex_colors(buf, row, line)
    local init = 1

    while true do
        -- find 6‑digit hex like #ff00aa / #FF00AA
        local s, e = line:find("#%x%x%x%x%x%x", init)
        if not s then break end

        local col0        = s - 1
        local color       = line:sub(s, e) -- "#rrggbb"
        local group       = "1337Hex_" .. color:sub(2) -- "1337Hex_ff00aa"

        -- compute a legible fg based on brightness of bg
        local fg_r        = tonumber(color:sub(2, 3), 16) or 0
        local fg_g        = tonumber(color:sub(4, 5), 16) or 0
        local fg_b        = tonumber(color:sub(6, 7), 16) or 0

        -- luminance formula
        local luminance   = (0.299 * fg_r) + (0.587 * fg_g) + (0.114 * fg_b)
        local computed_fg = (luminance > 186) and "#000000" or "#ffffff"

        -- bg is the hex, fg is auto-selected to maximize contrast
        vim.api.nvim_set_hl(0, group, { bg = color, fg = computed_fg })

        -- if you ONLY want these in comments, wrap this in `if in_comment(...) then ... end`
        vim.api.nvim_buf_add_highlight(buf, ns, group, row, col0, col0 + #color)

        init = e + 1
    end
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
        -- Comment tag highlights
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
        -- hex color highlighting (#000000 -> #ffffff)
        highlight_hex_colors(buf, row, line)
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
