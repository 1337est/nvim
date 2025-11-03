return {
    "nvim-lualine/lualine.nvim",
    enabled = true,
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
        local symbols = { error = ' ', warn = ' ', info = ' ', hint = ' ' }
        require("lualine").setup {
            options = {
                theme = "tokyonight",
                disabled_filetypes = {
                    statusline = { 'NvimTree' },
                    winbar = { 'NvimTree' },
                },
            },
            sections = {
                lualine_a = { { "mode" } },
                lualine_b = { { "diagnostics", symbols = symbols, color = { bg = '#232323' } } },
                lualine_c = { { "filename", path = 4 } },
                lualine_x = { {
                    "filetype",
                    icon = { align = 'left' }
                } },
                lualine_y = {
                    { "branch", color = { bg = '#232323' } },
                    { "diff",   color = { bg = '#323232' } },
                },
                lualine_z = { "location", "progress" },
            },
            inactive_sections = {
                lualine_a = { "filename" },
                lualine_z = { "location", "progress" },
            },
        }
    end,
}
