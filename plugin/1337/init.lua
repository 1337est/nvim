local utils = require("utils")
local autocmd = utils.autocmd
local map = utils.map

-- paste over without yanking / delete without yanking
map({ mode = "x", keys = "<leader>p", owner = "1337", desc = "paste over without yanking", fn = [["_dP]] })
map({ mode = { "n", "v" }, keys = "<leader>d", owner = "1337", desc = "delete without yanking", fn = [["_d]] })

map({ mode = "n", keys = "<Esc><Esc>", owner = "1337", desc = "Clears search highlights", fn = ":nohlsearch<CR>" })
-- keep search results centered
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

-- reloading config
map({ mode = "n", keys = "<leader>r", owner = "1337", desc = "write and reload file", fn = ":w<CR>:so<CR>" })

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
