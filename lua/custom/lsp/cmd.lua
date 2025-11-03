local augroup = vim.api.nvim_create_augroup
local autocmd = vim.api.nvim_create_autocmd

local lsp_attach_group = augroup("lsp-attach", { clear = true })
autocmd("LspAttach", {
    desc = "Sets keybindings when a LSP attaches to a buffer",
    group = lsp_attach_group,
    callback = function(e)
        local keys = require("custom.lsp.keys")
        local client = vim.lsp.get_client_by_id(e.data.client_id)

        if client then
            keys.setup(e.buf, client)
        end

        if client and client.supports_method('textDocument/formatting') then
            -- Format the current buffer on save
            autocmd('BufWritePre', {
                buffer = e.buf,
                callback = function()
                    vim.lsp.buf.format({ bufnr = e.buf, id = client.id })
                end,
            })
        end

        if client and client.supports_method(vim.lsp.protocol.Methods.textDocument_documentHighlight) then
            local lsp_hl_group = augroup('lsp-highlight', { clear = false })
            autocmd({ 'CursorHold', 'CursorHoldI' }, {
                buffer = e.buf,
                group = lsp_hl_group,
                callback = vim.lsp.buf.document_highlight,
            })
            autocmd({ 'CursorMoved', 'CursorMovedI' }, {
                buffer = e.buf,
                group = lsp_hl_group,
                callback = vim.lsp.buf.clear_references,
            })
        end
    end,
})

local lsp_detach_group = augroup("lsp-detach", { clear = true })
autocmd("LspDetach", {
    desc = "Clears LSP highlights on detach",
    group = lsp_detach_group,
    callback = function(e)
        vim.lsp.buf.clear_references()
        vim.api.nvim_clear_autocmds({ group = "lsp-highlight", buffer = e.buf })
    end,
})
