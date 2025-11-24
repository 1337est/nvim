require 'nvim-treesitter.configs'.setup {
    ensure_installed = {
        -- The listed parsers must always be installed
        "c",
        "lua",
        "vim",
        "vimdoc",
        "query",
        "markdown",
        "markdown_inline",

        -- Extras below
        "diff",
        "html",
        "luadoc",

        -- Extra extra's below
        "go",
        "hyprlang",
        "nu",
        "rust",
        "zig",
    },
    -- Install parsers synchronously (only applied to `ensure_installed`)
    sync_install = false,

    -- Automatically install missing parsers when entering buffer
    -- Recommendation: set to false if you don't have `tree-sitter` CLI installed locally
    auto_install = true,

    -- List of parsers to ignore installing (or "all")
    ignore_install = { "javascript" },

    parser_install_dir = vim.fn.stdpath("config"),

    highlight = {
        enable = true,
        -- Some languages depend on vim's regex highlighting system (such as Ruby) for indent rules.
        --  If you are experiencing weird indenting issues, add the language to
        --  the list of additional_vim_regex_highlighting and disabled languages for indent.
        additional_vim_regex_highlighting = { 'ruby' },
    },

    indent = { enable = true, disable = { 'ruby' } },
}
