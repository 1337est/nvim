-- disable netrw
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

vim.opt.guicursor = ""

vim.opt.number = true -- Make line numbers default
vim.opt.relativenumber = true -- Shows line # away from current line #
vim.opt.wrap = false -- Don't wrap text

vim.opt.breakindent = true -- Makes text-wrap visually indented for continuity
vim.opt.smartindent = true -- Smart auto-indenting on new lines
vim.opt.linebreak = true -- Wraps words instead of characters

vim.opt.tabstop = 4 -- tabs are 4 spaces
vim.opt.softtabstop = 4 -- indent 4 spaces visually
vim.opt.shiftwidth = 4 -- 4 spaces for (auto)indenting
vim.opt.expandtab = true -- Use appropriate spaces to insert tabs

vim.opt.undofile = true -- Save undo history

vim.opt.hlsearch = true -- Set highlight on search
vim.opt.incsearch = true -- Shows pattern match as you type

vim.opt.termguicolors = true -- Enables 24-bit RGB color

vim.opt.scrolloff = 5 -- Minimal number of screen lines above/below the cursor
vim.opt.signcolumn = "yes" -- When and how to draw the signcolomn

-- Case-insensitive searching UNLESS \C or there's capital letters in the search
vim.opt.ignorecase = true
vim.opt.smartcase = true

vim.opt.updatetime = 250 -- In 250ms if nothing is typed, write to swap file

-- Decrease mapped sequence wait time
-- Displays which-key popup sooner
vim.opt.timeoutlen = 300

-- Configure how new splits should be opened
vim.opt.splitright = true
vim.opt.splitbelow = true

-- Sets how neovim will display certain whitespace characters in the editor.
--  See `:help 'list'`
--  and `:help 'listchars'`
vim.opt.list = true
vim.opt.listchars = { tab = "» ", trail = "·", nbsp = "␣" }

-- Preview substitutions live as you type
vim.opt.inccommand = "split"

vim.opt.cursorline = true -- Show which line your cursor is on

vim.opt.colorcolumn = "80" -- Line at the 80th column

vim.opt.mouse = "a" -- Enables mouse mode

vim.opt.showmode = false -- Don't show mode, since it's already in status line

-- Sync clipboard between OS and Neovim.
--  Remove this option if you want your OS clipboard to remain independent.
--  See `:help 'clipboard'`
vim.opt.clipboard = "unnamedplus"
