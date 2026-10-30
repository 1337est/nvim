local M = {}

function M.setup()
    vim.lsp.config("*", {
        capabilities = {
            textDocument = {
                semanticTokens = {
                    multilineTokenSupport = true,
                },
            },
        },
        root_markers = { ".git" },
    })

    local m = vim.lsp.protocol.Methods

    local lsp_attach_grp = vim.api.nvim_create_augroup("LSP.attach", { clear = true })
    local lsp_highlight_grp = vim.api.nvim_create_augroup("LSP.highlight", { clear = true })
    local lsp_detach_grp = vim.api.nvim_create_augroup("LSP.detach", { clear = true })

    vim.api.nvim_create_autocmd("LspAttach", {
        group = lsp_attach_grp,
        desc = "LSP: Buffer-local keymaps and features",
        callback = function(e)
            local bufnr = e.buf
            local client = vim.lsp.get_client_by_id(e.data.client_id)

            vim.keymap.set("n", "grd", vim.lsp.buf.definition, {
                buffer = bufnr,
                silent = true,
                desc = "LSP: goto definition",
            })
            vim.keymap.set("n", "grD", vim.lsp.buf.declaration, {
                buffer = bufnr,
                silent = true,
                desc = "LSP: goto declaration",
            })
            vim.keymap.set("n", "gW", vim.lsp.buf.workspace_symbol, {
                buffer = bufnr,
                silent = true,
                desc = "LSP: workspace symbols",
            })
            vim.keymap.set("n", "K", vim.lsp.buf.hover, {
                buffer = bufnr,
                silent = true,
                desc = "LSP: hover docs",
            })

            if client and client:supports_method(m.textDocument_inlayHint) then
                vim.keymap.set("n", "<leader>th", function()
                    local on = vim.lsp.inlay_hint.is_enabled({ bufnr = bufnr })
                    vim.lsp.inlay_hint.enable(not on, { bufnr = bufnr })
                end, {
                    buffer = bufnr,
                    silent = true,
                    desc = "LSP: [t]oggle inlay [h]ints",
                })
            end

            if client and client:supports_method(m.textDocument_formatting) then
                local format_grp = vim.api.nvim_create_augroup(("LSP.format_%d"):format(bufnr), { clear = true })

                vim.api.nvim_create_autocmd("BufWritePre", {
                    group = format_grp,
                    buffer = bufnr,
                    desc = "LSP: format on save",
                    callback = function()
                        vim.lsp.buf.format({
                            bufnr = bufnr,
                            id = client.id,
                            timeout_ms = 1500,
                        })
                    end,
                })
            end

            if client and client:supports_method(m.textDocument_documentHighlight) then
                vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
                    group = lsp_highlight_grp,
                    buffer = bufnr,
                    callback = vim.lsp.buf.document_highlight,
                })

                vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
                    group = lsp_highlight_grp,
                    buffer = bufnr,
                    callback = vim.lsp.buf.clear_references,
                })
            end
        end,
    })

    vim.api.nvim_create_autocmd("LspDetach", {
        group = lsp_detach_grp,
        desc = "LSP: clear references and buffer-local LSP autocmds on detach",
        callback = function(event)
            vim.lsp.buf.clear_references()
            vim.api.nvim_clear_autocmds({ group = lsp_highlight_grp, buffer = event.buf })
        end,
    })

    vim.lsp.enable({
        "clangd",
        "gopls",
        "lua_ls",
        "rust_analyzer",
    })
end

return M
