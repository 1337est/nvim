local utils = require("utils")
local augroup = utils.augroup
local autocmd = utils.autocmd

-- ===================== Generic autocmds =====================

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

-- ===================== LSP-related autocmds (events only) =====================
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

        -- Call mapping helper defined in plugin/map.lua
        if _G.LspBufKeymaps then
            pcall(_G.LspBufKeymaps, bufnr, client)
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
