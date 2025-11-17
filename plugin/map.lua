local utils = require("utils")
local augroup = utils.augroup
local autocmd = utils.autocmd
local map = utils.map

-- =========================== Search / Telescope / Functions / Maps ============================

map({ mode = "x", keys = "<leader>p", owner = "1337", desc = "paste over without yanking", fn = [["_dP]] })
map({ mode = { "n", "v" }, keys = "<leader>d", owner = "1337", desc = "delete without yanking", fn = [["_d]] })

map({ mode = "n", keys = "<leader>c", owner = "1337", desc = "Clears search highlights", fn = ":nohlsearch<CR>" })
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

map({ mode = "n", keys = "<leader>sd", owner = "TEL", desc = "search diagnostics list", fn = tel.diagnostics })

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
