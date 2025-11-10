return {
    "folke/tokyonight.nvim",
    lazy = false,
    priority = 1000,
    config = function()
        require("tokyonight").setup {
            style = "storm",
            transparent = true,
            on_colors = function(colors)
                colors.fg_gutter = "#bbbbbb"
            end,
            on_highlights = function(highlights)
                highlights.CursorLine = { bg = "#292e32" }
                highlights.ColorColumn = { bg = "#aa2323" }
                highlights.LspReferenceText = { bg = "#7b6f00" }
                highlights.LspReferenceRead = { bg = "#7b6f00" }
                highlights.LspReferenceWrite = { bg = "#7b6f00" }
                highlights.EndOfBuffer = { fg = "#999999" }
            end,
        }
        require("tokyonight").load()
        vim.api.nvim_set_hl(0, "@markup.strong", { bold = true })
        vim.api.nvim_set_hl(0, "@markup.underline", { underline = true })
        vim.api.nvim_set_hl(0, "@text.strong", { bold = true })
        vim.api.nvim_set_hl(0, "@text.underline", { underline = true })
    end,
}
