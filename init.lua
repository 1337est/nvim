-- colorscheme, from colors/ dir

vim.cmd.colorscheme("1337dark")

-- settings

vim.g.mapleader = " "
vim.g.maplocalleader = " "
vim.g.have_nerd_font = true

vim.schedule(function() vim.opt.clipboard = "unnamedplus" end)

vim.opt.number = true
vim.opt.relativenumber = true

vim.opt.foldlevel = 99

vim.opt.cursorline = true
vim.opt.colorcolumn = "80"

vim.opt.expandtab = true
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.smartindent = true

vim.opt.list = true
vim.opt.listchars = { tab = "<->", trail = ".", nbsp = "-" }

vim.opt.showmode = false
vim.opt.showtabline = 2

vim.opt.splitright = true
vim.opt.splitbelow = true

vim.opt.winblend = 10

vim.opt.wrap = false
vim.opt.linebreak = true
vim.opt.scrolloff = 1
vim.opt.sidescrolloff = 1

vim.opt.undofile = true
vim.opt.swapfile = false

vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.inccommand = "split"
vim.opt.iskeyword:append("-")

vim.opt.updatetime = 300
vim.opt.timeoutlen = 300

vim.opt.autocomplete = true
vim.opt.completeopt = "menuone,noinsert,noselect"
vim.opt.pumheight = 10
vim.opt.pumblend = 15

local format_opts_remove_cro = vim.api.nvim_create_augroup("1337.format_opts_remove_cro", { clear = true })
vim.api.nvim_create_autocmd("BufEnter", {
    group = format_opts_remove_cro,
    pattern = "*",
    callback = function()
        vim.opt.formatoptions:remove({ "c", "r", "o" })
    end,
    desc = "1337: Removes automatic continuation comments",
})

local wrap_spell_on_ft = vim.api.nvim_create_augroup("1337.wrap_spell_on_ft", { clear = true })
vim.api.nvim_create_autocmd("FileType", {
    group = wrap_spell_on_ft,
    pattern = "*",
    callback = function()
        local ft = vim.bo.filetype
        if ft == "markdown" or ft == "norg" or ft == "text" then
            vim.opt_local.wrap = true
            vim.opt_local.spell = true
        end
    end,
    desc = "1337: Enables wrap+spell for prose-like filetypes",
})

-- keymaps

vim.keymap.set("x", "<leader>p", [["_dP]], { silent = true, desc = "1337: paste over without yanking" })
vim.keymap.set({ "n", "v" }, "<leader>d", [["_d]], { silent = true, desc = "1337: delete without yanking" })
vim.keymap.set("n", "<leader><C-l>", "<cmd>nohlsearch<cr>", { silent = true, desc = "1337: Clears search highlights" })
vim.keymap.set("n", "J", "mzJ`z", { silent = true, desc = "1337: Join lines, keep cursor position" })

-- autocommands

local mkview_on_leave = vim.api.nvim_create_augroup("1337.mkview_on_leave", { clear = true })
vim.api.nvim_create_autocmd("BufWinLeave", {
    group = mkview_on_leave,
    pattern = "*.*",
    command = "mkview",
    desc = "1337: mkview on window leave",
})

local loadview_on_enter = vim.api.nvim_create_augroup("1337.loadview_on_enter", { clear = true })
vim.api.nvim_create_autocmd("BufWinEnter", {
    group = loadview_on_enter,
    pattern = "*.*",
    command = "silent! loadview",
    desc = "1337: loadview on window enter",
})

local hl_on_yank = vim.api.nvim_create_augroup("1337.hl_on_yank", { clear = true })
vim.api.nvim_create_autocmd("TextYankPost", {
    group = hl_on_yank,
    pattern = "*",
    callback = function()
        vim.hl.on_yank({ higroup = "IncSearch", timeout = 40 })
    end,
    desc = "1337: Brief highlight on yank",
})

-- diagnostics

vim.diagnostic.config({
    severity_sort = true,
    float = { border = "rounded", source = "if_many" },
    underline = { severity = vim.diagnostic.severity.ERROR },
    signs = vim.g.have_nerd_font and {
        text = {
            [vim.diagnostic.severity.ERROR] = "󰅚 ",
            [vim.diagnostic.severity.WARN] = "󰀪 ",
            [vim.diagnostic.severity.INFO] = "󰋽 ",
            [vim.diagnostic.severity.HINT] = "󰌶 ",
        },
    } or {},
    virtual_text = {
        source = "if_many",
        spacing = 2,
    },
})

-- lua/*.lua plugin files

require("syntax").setup({ cst = "treesitter" })
require("vc").setup()
require("ui").setup()
require("lsp").setup()
require("explorer").setup()
require("debugger").setup()
require("terminal").setup({
    header = { name = "floaterminal", pos = "left" },
    footer = { name = "1337est", pos = "right" },
})
require("textpairs").setup()
require("modekeymapper").setup()

require("zwe").setup({
    cmd = vim.fn.expand("~/.local/bin/zwe"),

    mappings = {
        definition = "gd",
        completion = false,
        symbols = "<leader>zs",
    },

    diagnostics = false,
    definition_fallback = true,
})
