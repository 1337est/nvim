return {
    "folke/todo-comments.nvim",
    enabled = true,
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
        require("todo-comments").setup {
            colors = {
                error = { "#f65866" },   -- red
                warning = { "#efbd5d" }, -- yellow
                info = { "#41a7fc" },    -- blue
                hint = { "#c75ae8" },    -- purple
                default = { "#8bcd5b" }, -- green
                test = { "#34bfd0" },    -- cyan
            },
        }
    end,
}
