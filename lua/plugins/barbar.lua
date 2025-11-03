return {
    {
        'romgrk/barbar.nvim',
        dependencies = {
            'lewis6991/gitsigns.nvim',
            'nvim-tree/nvim-web-devicons',
        },
        init = function()
            vim.g.barbar_auto_setup = false
        end,
        config = function()
            require("barbar").setup {}
            vim.api.nvim_set_hl(0, 'BufferCurrent', { fg = '#1c2526', bg = '#d0d0d0', bold = true })
            vim.api.nvim_set_hl(0, 'BufferCurrentSign', { fg = '#1c2526', bg = '#d0d0d0' })
            vim.api.nvim_set_hl(0, 'BufferCurrentMod', { fg = '#a8334c', bg = '#d0d0d0', bold = true })
            vim.api.nvim_set_hl(0, 'BufferVisible', { fg = '#4a5859', bg = '#e0e0e0' })
            vim.api.nvim_set_hl(0, 'BufferVisibleSign', { fg = '#4a5859', bg = '#e0e0e0' })
            vim.api.nvim_set_hl(0, 'BufferInactive', { fg = '#6b7280', bg = '#f0f0f0' })
            vim.api.nvim_set_hl(0, 'BufferInactiveSign', { fg = '#6b7280', bg = '#f0f0f0' })
            vim.api.nvim_set_hl(0, 'BufferTabpageFill', { fg = '#6b7280', bg = '#f5f5f5' })
        end,
    },
}
