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
vim.o.winbar           = "%f"
vim.o.tabline          = ""

-----------------------------------------------------------------------------------
-- BEHAVIOR: BUFFERS / VIEWPORTS / RENDERING / WRITING / READING / WINDOWS / TABS / FLOATS / POPUPS
-----------------------------------------------------------------------------------
vim.opt.autoread       = true
vim.opt.autowrite      = false
vim.opt.autochdir      = false
vim.opt.confirm        = true

vim.opt.splitright     = true -- new splits open right
vim.opt.splitbelow     = true -- new splits open below
vim.opt.winblend       = 10

vim.opt.wrap           = false -- Don't wrap text
vim.opt.spell          = false
vim.opt.linebreak      = true -- Wraps words instead of characters
vim.opt.scrolloff      = 1 -- Minimal screen lines above/below the cursor
vim.opt.sidescrolloff  = 1 -- Minimal screen lines to keep left/right

-- undo state
vim.opt.undodir        = vim.fn.stdpath("state") .. "/undodir//"
vim.opt.undofile       = true -- Save undo history

-- view state
vim.opt.viewdir        = vim.fn.stdpath("state") .. "/viewdir//"

-- backup state
vim.opt.backup         = false
vim.opt.writebackup    = false
-- swap state
vim.opt.swapfile       = false

----------------------------------------------------------------------------------------------
-- ACTIONS: FINDING / SEARCHING / NAVIGATION / EXPLORER / MARKS / JUMPS / COMPLETIONS / MOVES
----------------------------------------------------------------------------------------------
-- Sync clipboard between OS and Neovim.
--  Remove this option if you want your OS clipboard to remain independent.
--  See `:help 'clipboard'`
vim.schedule(function() vim.opt.clipboard = "unnamedplus" end)

-- searching
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.incsearch = true -- Shows pattern match as you type
vim.opt.inccommand = "split" -- preview substitutions live as you type
vim.opt.hlsearch = true -- Set highlight on search
vim.opt.iskeyword:append("-")

-- mouse
vim.opt.mouse = "a" -- Enables mouse mode
vim.opt.mousescroll = "ver:1,hor:1"

-- completions
vim.opt.updatetime = 250 -- Time after CursorHold Event (faster completions)
vim.opt.timeoutlen = 300 -- Mapped key sequence wait time
vim.opt.completeopt = "menuone,noinsert,noselect"
vim.opt.pumheight = 10
vim.opt.pumblend = 10

-- =============== LSP ===============

-- Optional: default settings applied to *all* configs (wildcard "*")
-- You can keep this minimal; root_markers helps autostart at project roots.
vim.lsp.config('*', {
    capabilities = {
        textDocument = {
            semanticTokens = {
                multilineTokenSupport = true,
            },
        },
    },
    root_markers = { '.git' },
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
