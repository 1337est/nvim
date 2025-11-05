-- $Project: Minimal Neovim$
-- $File: init.lua$
-- $Date: 2025-11-05$
-- $Revision: 1$
-- $Author: Adrian Sanchez$
-- $Notice: $

-- set.lua ---------------------------------------------------------------------

-- Terminal settings
vim.opt.termguicolors = true

-- Font settings
vim.g.have_nerd_font = true

-- Colorscheme settings
vim.cmd.colorscheme("unokai") -- TODO: look up how to create your own colorscheme in colors dir?

-- Transparency settings
vim.api.nvim_set_hl(0, "Normal", { bg = "none" }) -- TODO: Normal?
vim.api.nvim_set_hl(0, "NormalNC", { bg = "none" }) -- TODO: NormalNC?
vim.api.nvim_set_hl(0, "EndOfBuffer", { bg = "none" }) -- TODO: EndOfBuffer?

-- Gutter & Column Display settings
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.signcolumn = "yes"
vim.opt.colorcolumn = "100"

-- Cursor & Mouse settings
vim.opt.guicursor = ""
vim.opt.cursorline = true
vim.opt.mouse = "a"
vim.opt.mousescroll = "ver:1,hor:1"

-- Text View, Conceal, & List settings
vim.opt.wrap = false
vim.opt.linebreak = true

vim.opt.scrolloff = 4
vim.opt.sidescrolloff = 2

vim.opt.conceallevel = 0
vim.opt.concealcursor = ""

vim.opt.list = true
vim.opt.listchars = {
    tab = "<->", trail = ".", nbsp = "_"
}

-- Indent settings
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.softtabstop = 4
vim.opt.expandtab = true
vim.opt.smartindent = true
vim.opt.breakindent = true

-- Search settings
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.hlsearch = true
vim.opt.incsearch = true
vim.opt.iskeyword:append("-")

-- Completion settings
vim.opt.completeopt = "menuone,noinsert,noselect"

-- Status line settings
vim.opt.showmode = true

-- Popup Menu settings
vim.opt.pumheight = 10
vim.opt.pumblend = 10

-- Floating Window settings
vim.opt.winblend = 0

-- Screen Rendering settings
vim.opt.lazyredraw = true

-- Backup settings
vim.opt.backup = false
vim.opt.writebackup = false

-- Swapfile settings
vim.opt.swapfile = false

-- Undodir settings
vim.opt.undofile = true
vim.opt.undodir = vim.fn.stdpath("state") .. "/undodir"

-- Viewdir settings
vim.opt.viewdir = vim.fn.stdpath("state") .. "/viewdir"

-- ??? settings
vim.opt.updatetime = 300
vim.opt.timeoutlen = 500
vim.opt.autoread = true
vim.opt.autowrite = false

-- File Navigation settings
vim.opt.autochdir = true

-- Split Window settings
vim.opt.inccommand = "split"
vim.opt.splitright = true
vim.opt.splitbelow = true

-- Clipboard settings (TODO: have function for if on Windows)
vim.schedule(function()
    vim.opt.clipboard = "unnamedplus"
end)

-- keys.lua --------------------------------------------------------------------

vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- Preserves text instead of replacing the register with the deleted text by
-- deleting text into the 'blackhole' register "_d.
vim.keymap.set("v", "<leader>kp", [["_dP]], { desc = "[k]eep [p]aste" })
vim.keymap.set({ "n", "v" }, "<leader>kd", [["_d]], { desc = "[k]eep [d]elete" })

-- Set highlight on search, but clear on pressing <Esc> in normal mode
vim.keymap.set("n", "<Esc>", "<cmd>nohlsearch<CR>")

-- Diagnostic keymaps
vim.keymap.set("n", "[d", vim.diagnostic.goto_prev, { desc = "Previous [d]iagnostic" })
vim.keymap.set("n", "]d", vim.diagnostic.goto_next, { desc = "Next [d]iagnostic" })
vim.keymap.set("n", "<leader>e", vim.diagnostic.open_float,
    { desc = "Show diagnostic [e]rror messages" })
vim.keymap.set("n", "<leader>q", vim.diagnostic.setloclist,
    { desc = "Open diagnostic [q]uickfix list" })

-- Manual auto-formatting
vim.keymap.set("n", "<leader>f", function()
    local save_cursor = vim.fn.getcurpos()
    vim.cmd("normal gg=G")
    vim.fn.setpos('.', save_cursor)
end, { desc = "[f]ormat File" })

-- cmd.lua ---------------------------------------------------------------------

local augroup = vim.api.nvim_create_augroup
local autocmd = vim.api.nvim_create_autocmd

local yank_group = augroup("HighlightYank", {})
autocmd("TextYankPost", {
    desc = "Hightlight when yanking (copying) text",
    group = yank_group,
    pattern = "*",
    callback = function()
        vim.hl.on_yank({
            higroup = "IncSearch",
            timeout = 40,
        })
    end,
})

local fold_group = augroup("remember_folds", { clear = true })
autocmd({ "BufWinLeave" }, {
    group = fold_group,
    pattern = "*.*",
    command = "mkview",
})
autocmd({ "BufWinEnter" }, {
    group = fold_group,
    pattern = "*.*",
    command = "silent! loadview",
})

-- Enables wrap text for Markdown and Text files
vim.cmd([[autocmd BufEnter *.md,*.txt,*.norg set wrap]])
-- Enable spell checking for Markdown and Text files
vim.cmd([[autocmd BufEnter *.md,*.txt,*.norg set spell]])

-- Getting rid of auto-inserted comments *spit* PFF-THUU *end-spit*
vim.cmd([[autocmd BufEnter * set formatoptions-=cro ]])

-- Experimentation starts here -------------------------------------------------


