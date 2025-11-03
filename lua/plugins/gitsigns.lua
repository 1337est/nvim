return {
    "lewis6991/gitsigns.nvim",
    enabled = true,
    config = function()
        require("gitsigns").setup {
            signs = {
                add = { text = "+" },
                change = { text = "~" },
            },
            signs_staged = {
                add = { text = "+" },
                change = { text = "~" },
            },
        }
    end,
}
