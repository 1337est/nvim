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
