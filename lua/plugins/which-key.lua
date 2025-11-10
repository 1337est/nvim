return {
    {
        "folke/which-key.nvim",
        event = "VimEnter", -- Sets the loading event to 'VimEnter'
        opts = {
            spec = {
                { "<leader>c", group = "[c]ode",      mode = { "n", "x" } },
                { "<leader>d", group = "[d]ocument",  mode = "n" },
                { "<leader>r", group = "[r]ename",    mode = "n" },
                { "<leader>s", group = "[s]earch",    mode = "n" },
                { "<leader>t", group = "[t]oggle",    mode = "n" },
                { "<leader>w", group = "[w]orkspace", mode = "n" },
                { "<leader>k", group = "[k]eep",      mode = { "n", "v" } },
                { "<leader>",  group = "Leader",      mode = { "n", "v" } },
                { "[",         group = "Previous",    mode = "n" },
                { "]",         group = "Next",        mode = "n" },
            }
        }
    },
}
