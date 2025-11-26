local utils = require("utils")
local augroup = utils.augroup
local autocmd = utils.autocmd
local map = utils.map

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

-- paste over without yanking / delete without yanking
map({ mode = "x", keys = "<leader>p", owner = "1337", desc = "paste over without yanking", fn = [["_dP]] })
map({ mode = { "n", "v" }, keys = "<leader>d", owner = "1337", desc = "delete without yanking", fn = [["_d]] })

map({ mode = "n", keys = "<leader><C-l>", owner = "1337", desc = "Clears search highlights", fn = ":nohlsearch<CR>" })
-- keep search results centered
map({ mode = "n", keys = "n", owner = "1337", desc = "next search centered", fn = "nzz" })
map({ mode = "n", keys = "N", owner = "1337", desc = "previoius search centered", fn = "Nzz" })
map({ mode = "n", keys = "<C-u>", owner = "1337", desc = "Half page up centered", fn = "<C-u>zz" })
map({ mode = "n", keys = "<C-d>", owner = "1337", desc = "Half page down centered", fn = "<C-d>zz" })
map({ mode = "n", keys = "<C-f>", owner = "1337", desc = "Full page up centered", fn = "<C-f>zz" })
map({ mode = "n", keys = "<C-b>", owner = "1337", desc = "Full page down centered", fn = "<C-b>zz" })
map({ mode = "n", keys = "J", owner = "1337", desc = "Join lines, keep cursor position", fn = "mzJ`z" })

-- Moving blocks of text with active selection via alt keys
map({ mode = "n", keys = "<A-j>", owner = "1337", desc = "Move line down", fn = ":m .+1<CR>==" })
map({ mode = "n", keys = "<A-k>", owner = "1337", desc = "Move line up", fn = ":m .-2<CR>==" })
map({ mode = "v", keys = "<A-j>", owner = "1337", desc = "Move selection down", fn = ":m '>+1<CR>gv=gv" })
map({ mode = "v", keys = "<A-k>", owner = "1337", desc = "Move selection up", fn = ":m '<-2<CR>gv=gv" })
map({ mode = "v", keys = "<A-.>", owner = "1337", desc = "Indent right reselect", fn = ">gv" })
map({ mode = "v", keys = "<A-,>", owner = "1337", desc = "Indent left reselect", fn = "<gv" })

-- Automatic mkview and loadview behavior
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

-- Highlights on yank
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
