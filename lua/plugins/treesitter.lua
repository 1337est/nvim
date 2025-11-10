return {
    -- syntax highlighting
    "nvim-treesitter/nvim-treesitter",
    enabled = true,
    build = ":TSUpdate",
    config = function()
        require("nvim-treesitter.configs").setup({
            ensure_installed = {
                -- defaults
                "c",
                "cpp",
                "lua",
                "vim",
                "vimdoc",
                "query",
                "go",

                "hyprlang",
                "bash",
                "nu",
                "markdown",
                "markdown_inline",
                "rust",
                "zig",
            },
            -- Install parsers synchronously (only applied to `ensure_installed`)
            sync_install = false,

            -- Autoinstall languages that are not installed
            auto_install = true,
            ignore_install = { "javascript" },
            highlight = {
                enable = true,
                -- list of language that will be disabled
                disable = {},
                additional_vim_regex_highlighting = { "ruby" },
            },
            indent = { enable = true, disable = { "ruby" } },
        })
        vim.filetype.add({
            pattern = {
                [".*/hypr/.*%.conf"] = "hyprlang",
            }
        })
    end,
}
