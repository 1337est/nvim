return {
    "lukas-reineke/indent-blankline.nvim",
    main = "ibl",
    opts = {},
    config = function()
        require("ibl").setup {
            exclude = { filetypes = {
                "lspinfo",
                "packer",
                "checkhealth",
                "help",
                "man",
                "gitcommit",
                "TelescopePrompt",
                "TelescopeResults",
                "",
                "dashboard",
            } }
        }
    end,
}
