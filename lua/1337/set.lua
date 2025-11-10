-- Basic settings
vim.g.mapleader = " "         -- Sets space as the leader key
vim.g.maplocalleader = " "    -- Sets space as the leader key
vim.opt.number = true         -- Make line numbers default
vim.opt.relativenumber = true -- Shows line # away from current line #
vim.opt.cursorline = true     -- Show which line your cursor is on
vim.opt.wrap = false          -- Don't wrap text
vim.opt.linebreak = true      -- Wraps words instead of characters
vim.opt.scrolloff = 8         -- Minimal screen lines above/below the cursor
vim.opt.sidescrolloff = 3     -- Minimal screen lines to keep left/right

-- Indentation
vim.opt.tabstop = 4        -- tabs are 4 spaces
vim.opt.shiftwidth = 4     -- 4 spaces for (auto)indenting
vim.opt.softtabstop = 4    -- indent 4 spaces visually
vim.opt.expandtab = true   -- Use appropriate spaces to insert tabs
vim.opt.smartindent = true -- Smart auto-indenting on new lines
vim.opt.breakindent = true -- Makes text-wrap visually indented for continuity

-- Search settings
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.hlsearch = true  -- Set highlight on search
vim.opt.incsearch = true -- Shows pattern match as you type

-- Visual settings
vim.g.have_nerd_font = true  -- For my nerd font
vim.opt.termguicolors = true -- Enables 24-bit RGB color
vim.opt.guicursor = ""       -- Disable cursor styling
vim.opt.signcolumn = "yes"   -- Show sign column
vim.opt.colorcolumn = "100"  -- Line at the nth column
vim.opt.completeopt = "menuone,noinsert,noselect"
vim.opt.showmode = false     -- Don't show mode, since it's already in status line
vim.opt.pumheight = 10
vim.opt.pumblend = 10
vim.opt.winblend = 0
vim.opt.conceallevel = 0
vim.opt.concealcursor = ""
vim.opt.lazyredraw = true
vim.opt.list = true
vim.opt.listchars = {
    tab = "» ", trail = "·", nbsp = "␣", extends = "▶", precedes = "◀"
}

-- File handling
vim.opt.backup = false
vim.opt.writebackup = false
vim.opt.swapfile = false
vim.opt.undofile = true -- Save undo history
vim.opt.undodir = vim.fn.stdpath("state") .. "/undodir"
vim.opt.viewdir = vim.fn.stdpath("state") .. "/viewdir"
vim.opt.updatetime = 300 -- Faster completion
vim.opt.timeoutlen = 500 -- Mapped key sequence wait time
vim.opt.autoread = true
vim.opt.autowrite = false

-- Behavior settings
vim.opt.autochdir = true
vim.opt.splitright = true    -- new splits open right
vim.opt.splitbelow = true    -- new splits open below
vim.opt.inccommand = "split" -- preview substitutions live as you type
vim.opt.mouse = "a"          -- Enables mouse mode
vim.opt.mousescroll = "ver:1,hor:1"
vim.opt.iskeyword:append("-")

-- Sync clipboard between OS and Neovim.
--  Remove this option if you want your OS clipboard to remain independent.
--  See `:help 'clipboard'`
vim.schedule(function()
    vim.opt.clipboard = "unnamedplus"
end)
