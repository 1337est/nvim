local M = {}

M.setup = function(bufnr, client)
    local map = function(keys, func, desc)
        vim.keymap.set("n", keys, func,
            { buffer = bufnr, desc = "LSP: " .. desc })
    end

    local telebuilt = require('telescope.builtin')
    map("gd", telebuilt.lsp_definitions, "[g]oto [d]efinition")
    map("gD", function() vim.lsp.buf.declaration() end, "[g]oto [D]eclaration")
    map("gI", telebuilt.lsp_implementations, "[g]oto [I]mplementation")
    map("gr", telebuilt.lsp_references, "[g]oto [r]eferences")

    map("<leader>D", telebuilt.lsp_type_definitions, "Type [D]efinition")
    map("<leader>ds", telebuilt.lsp_document_symbols, "[d]ocument [s]ymbols")
    map("<leader>ws", telebuilt.lsp_dynamic_workspace_symbols, "[w]orkspace [s]ymbols")

    map("<leader>rn", function() vim.lsp.buf.rename() end, "[r]e[n]ame")
    map("<leader>ca", function() vim.lsp.buf.code_action() end, "[c]ode [a]ction")

    map("K", function() vim.lsp.buf.hover() end, "Shows Documentation")

    if client and client.supports_method(vim.lsp.protocol.Methods.textDocument_inlayHint) then
        map('<leader>th', function()
            vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled { bufnr = bufnr })
        end, '[t]oggle Inlay [h]ints')
    end
end

return M
