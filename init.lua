-- $Project: Minimal Neovim$
-- $File: init.lua$
-- $Date: 2025-11-05$
-- $Revision: 1$
-- $Author: Adrian Sanchez$
-- $Notice: $

--------------------------------------------------------------------------------
-- Basic Setup
--------------------------------------------------------------------------------

-- === Local Definitions ===
local augroup = vim.api.nvim_create_augroup
local yank_group = augroup("HighlightYank", {})
local fold_group = augroup("remember_folds", { clear = true })
local autocmd = vim.api.nvim_create_autocmd

-- === Leader Key ===
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- === Font Settings ===
vim.g.have_nerd_font = true

-- === Mouse Settings ===
vim.opt.mouse = "a"
vim.opt.mousescroll = "ver:1,hor:1"

-- === Gutter & Column Settings ===
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.signcolumn = "yes"
vim.opt.colorcolumn = "80"

-- === Indent Settings ===
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.softtabstop = 4
vim.opt.expandtab = true
vim.opt.smartindent = true
vim.opt.breakindent = true

-- === Text Wrap Settings ===
vim.opt.wrap = false
vim.opt.linebreak = true
-- === Text Scrolloff Settings ===
vim.opt.scrolloff = 4
vim.opt.sidescrolloff = 2
-- === Conceal Settings ===
vim.opt.conceallevel = 0
vim.opt.concealcursor = ""
vim.opt.list = true
vim.opt.listchars = {
    tab = "<->", trail = ".", nbsp = "+"
}

-- === Search Settings ===
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.hlsearch = true
vim.opt.incsearch = true
vim.opt.iskeyword:append("-")
-- Set highlight on search, but clear on pressing <Esc> in normal mode
vim.keymap.set("n", "<Esc>", "<cmd>nohlsearch<CR>")

-- === Buffer/Window/Tab/Screen Settings ===
-- Screen Rendering
vim.opt.lazyredraw = true
vim.opt.updatetime = 300
vim.opt.timeoutlen = 500
vim.opt.autoread = true
vim.opt.autowrite = false
-- Split Window Settings
vim.opt.inccommand = "split"
vim.opt.splitright = true
vim.opt.splitbelow = true

-- === Backup Settings ===
vim.opt.backupdir = vim.fn.stdpath("state") .. "/backupdir//"
vim.opt.backup = true
vim.opt.writebackup = true

-- === Swap Settings ===
vim.opt.directory = vim.fn.stdpath("state") .. "/swapdir//"
vim.opt.swapfile = true

-- === Undodir Settings ===
vim.opt.undodir = vim.fn.stdpath("state") .. "/undodir//"
vim.opt.undofile = true

-- === Viewdir Settings ===
vim.opt.viewdir = vim.fn.stdpath("state") .. "/viewdir//"
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

-- Register Settings (TODO: have function for if on Windows)
vim.schedule(function()
    vim.opt.clipboard = "unnamedplus"
end)
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
-- Preserves text instead of replacing the register with the deleted text by
-- deleting text into the 'blackhole' register "_d.
vim.keymap.set("v", "<leader>kp", [["_dP]], { desc = "[k]eep [p]aste" })
vim.keymap.set({ "n", "v" }, "<leader>kd", [["_d]], { desc = "[k]eep [d]elete" })

--------------------------------------------------------------------------------
-- Status line Settings
--------------------------------------------------------------------------------
vim.opt.showmode = true

--------------------------------------------------------------------------------
-- Completion & Popup Menu Settings :help ins-completion
--------------------------------------------------------------------------------
vim.opt.completeopt = "menuone,noinsert,noselect"
vim.opt.pumheight = 10
vim.opt.pumblend = 10

--------------------------------------------------------------------------------
-- Colorscheme & Fonts Settings
--------------------------------------------------------------------------------
vim.cmd.colorscheme("unokai") -- TODO: look up how to create your own colorscheme in colors dir?

-- Transparency Settings
vim.api.nvim_set_hl(0, "Normal", { bg = "none" }) -- TODO: Normal?
vim.api.nvim_set_hl(0, "NormalNC", { bg = "none" }) -- TODO: NormalNC?
vim.api.nvim_set_hl(0, "EndOfBuffer", { bg = "none" }) -- TODO: EndOfBuffer?

vim.opt.cursorline = true

-- Gui Settings
vim.opt.termguicolors = true
vim.opt.guicursor = ""

--------------------------------------------------------------------------------
-- Floating Window Settings
--------------------------------------------------------------------------------
vim.opt.winblend = 0

--------------------------------------------------------------------------------
-- File Navigation Settings
--------------------------------------------------------------------------------
vim.opt.autochdir = true

--------------------------------------------------------------------------------
-- Diagnostics TODO: put with lsp?
--------------------------------------------------------------------------------
vim.keymap.set("n", "[d", vim.diagnostic.goto_prev, { desc = "Previous [d]iagnostic" })
vim.keymap.set("n", "]d", vim.diagnostic.goto_next, { desc = "Next [d]iagnostic" })
vim.keymap.set("n", "<leader>e", vim.diagnostic.open_float,
    { desc = "Show diagnostic [e]rror messages" })
vim.keymap.set("n", "<leader>q", vim.diagnostic.setloclist,
    { desc = "Open diagnostic [q]uickfix list" })

--------------------------------------------------------------------------------
-- Formatting
--------------------------------------------------------------------------------
-- Getting rid of auto-inserted comments *spit* PFF-THUU *end-spit*
vim.opt.formatoptions:remove { "c", "r", "o" }

vim.keymap.set("n", "<leader>f", function()
    local save_cursor = vim.fn.getcurpos()
    vim.cmd("normal gg=G")
    vim.fn.setpos('.', save_cursor)
end, { desc = "[f]ormat File" })

-- Experimentation starts here -------------------------------------------------


