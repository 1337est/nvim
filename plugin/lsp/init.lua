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

-- Tip: you can enable/disable later too:
--   vim.lsp.enable('clangd', false)  -- stop/disable
--   vim.lsp.enable('clangd', true)   -- re-enable

local utils = require("utils")
local map = utils.map
local augroup = utils.augroup
local autocmd = utils.autocmd

local lsp_owner = "LSP"
local m = vim.lsp.protocol.Methods

-- This will be called from the LspAttach autocmd in plugin/cmd.lua
function _G.LspBufKeymaps(bufnr, client)
    local function bmap(spec)
        spec.opts = vim.tbl_extend("keep", spec.opts or {}, { buffer = bufnr })
        map(spec)
    end

    -- core LSP maps
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

    -- optional inlay hints toggle
    if client and client:supports_method(m.textDocument_inlayHint) then
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
end

local lsp_attach_grp = augroup(lsp_owner, 'attach')

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

        if client and client:supports_method(m.textDocument_formatting) then
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
    end,
})
