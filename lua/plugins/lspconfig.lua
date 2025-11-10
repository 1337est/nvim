return {
    "neovim/nvim-lspconfig",
    enabled = true,
    dependencies = {
        { "mason-org/mason.nvim", opts = {} }, -- manages LSP, DAP, linters, formatters
        "mason-org/mason-lspconfig.nvim",      -- integrates mason & lspconfig
        { 'j-hui/fidget.nvim',    opts = {} },
        "saghen/blink.cmp",                    -- adds more completions for LSP's
    },

    config = function()
        require("custom.lsp.cmd")

        local lsp_servers = require("custom.lsp.servers")
        local servers = lsp_servers.servers
        local capabilities = lsp_servers.capabilities

        require("mason-lspconfig").setup({
            ensure_installed = vim.tbl_keys(servers),
            handlers = {
                function(server_name)
                    local server = servers[server_name] or {}
                    server.capabilities = vim.tbl_deep_extend("force", {}, capabilities,
                        server.capabilities or {})
                    require("lspconfig")[server_name].setup(server)
                end,
            },
        })
    end,
}
