-- Optional: default settings applied to *all* configs (wildcard "*")
-- You can keep this minimal; root_markers helps autostart at project roots.
vim.lsp.config('*', {
    capabilities = {
        textDocument = {
            semanticTokens = {
                multilineTokenSupport = true,
            },
        },
    },
    root_markers = { '.git' },
})

-- Helper: collect LSP names from lua/nvim/lsp/<name>.lua on runtimepath
local function get_lsp_file_names()
    -- This searches every directory on 'runtimepath' for lua/nvim/lsp/<name>.lua
    local files = vim.api.nvim_get_runtime_file('lsp/*.lua', true)

    local names_seen = {}
    local names = {}

    for _, path in ipairs(files) do
        -- Normalize Windows slashes
        local normalized = path:gsub("\\", "/")

        -- extract "<name>.lua" from "nvim/lsp/<name>.lua
        local name = normalized:match("nvim/lsp/([^/]+)%.lua$")

        -- skip helper files if you have any, e.g. init.lua, utils.lua, etc.
        if name and name ~= "init" and not names_seen[name] then
            names_seen[name] = true
            table.insert(names, name)
        end
    end

    return names
end

-- Auto-enable all LSP configs that have a lua/nvim/lsp/<name>.lua file
-- Once enabled, Neovim auto-starts the server on buffers matching filetypes
-- and rooted by root_markers/root_dir.
vim.lsp.enable(get_lsp_file_names())
