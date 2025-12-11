return {
    "loctvl842/monokai-pro.nvim",
    config = function()
        require("monokai-pro").setup({})
        vim.cmd([[colorscheme monokai-pro-octagon]])
    end
}
