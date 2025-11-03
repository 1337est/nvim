return {
    "nvim-tree/nvim-tree.lua",
    version = "*",
    lazy = false,
    dependencies = {
        "nvim-tree/nvim-web-devicons",
    },
    config = function()
        -- disable netrw
        vim.g.loaded_netrw = 1
        vim.g.loaded_netrwPlugin = 1
        local api = require "nvim-tree.api"

        -- setup on_attach settings
        local function my_on_attach(bufnr)
            local function opts(desc)
                return { desc = "nvim-tree: " .. desc, buffer = bufnr, noremap = true, silent = true, nowait = true }
            end

            -- default mappings
            api.config.mappings.default_on_attach(bufnr)

            -- custom mappings
            vim.keymap.set("n", "?", api.tree.toggle_help, opts("Help"))
        end

        -- pass to setup along with your other options
        require("nvim-tree").setup {
            ---
            on_attach = my_on_attach,
            ---
        }

        -- to prevent statusline from showing for NvimTree
        api.events.subscribe("TreeOpen", function()
            vim.wo.statusline = ' '
        end)
        vim.keymap.set("n", "<leader>tf", api.tree.toggle,
            { desc = "nvim-tree: [t]oggle [f]ileExplorer", noremap = true, silent = true, nowait = true })
    end,
}
