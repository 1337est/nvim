local utils = require("utils")
local map = utils.map

-- =========================== Search / Telescope / Functions / Maps ============================

-- paste over without yanking / delete without yanking
map({ mode = "x", keys = "<leader>p", owner = "1337", desc = "paste over without yanking", fn = [["_dP]] })
map({ mode = { "n", "v" }, keys = "<leader>d", owner = "1337", desc = "delete without yanking", fn = [["_d]] })

map({ mode = "n", keys = "<leader>c", owner = "1337", desc = "Clears search highlights", fn = ":nohlsearch<CR>" })
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

-- File Explorering
map({ mode = "n", keys = "<leader>e", owner = "1337", desc = "Explorer", fn = ":Oil<CR>" })

-- reloading config
map({ mode = "n", keys = "<leader>r", owner = "1337", desc = "write and reload file", fn = ":w<CR>:so<CR>" })

-- ===================== Telescope setup + maps =====================

do
    local ok_telescope, telescope = pcall(require, "telescope")
    if ok_telescope then
        telescope.setup {
            extensions = { ["ui-select"] = require("telescope.themes").get_dropdown(), },
            pickers = { find_files = { hidden = true, no_ignore = true, no_ignore_parent = true }, },
            defaults = { file_ignore_patterns = { "undodir", "node_modules" }, },
        }
    end
    local ok_tel, tel = pcall(require, 'telescope.builtin')
    if ok_tel then
        map({ mode = "n", keys = "<leader>st", owner = "TEL", desc = "telescope builtins", fn = tel.builtin })

        map({ mode = "n", keys = "<leader>sk", owner = "TEL", desc = "search nvim keymaps", fn = tel.keymaps })
        map({ mode = "n", keys = "<leader>sh", owner = "TEL", desc = "search nvim help_tags", fn = tel.help_tags })

        map({ mode = "n", keys = "<leader>sf", owner = "TEL", desc = "search file by name from cwd", fn = tel.find_files })
        map({ mode = "n", keys = "<leader>so", owner = "TEL", desc = "search file by name from file history", fn = tel.oldfiles })
        map({ mode = "n", keys = "<leader>sb", owner = "TEL", desc = "Find existing buffers", fn = tel.buffers })

        map({ mode = "n", keys = "<leader>s/", owner = "TEL", desc = "search word with dynamic grep", fn = tel.live_grep })

        map({ mode = "n", keys = "<leader>sd", owner = "TEL", desc = "search diagnostics list", fn = tel.diagnostics })
    end
end

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
