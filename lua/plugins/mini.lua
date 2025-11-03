return {
    'echasnovski/mini.nvim',
    version = false,
    config = function()
        local ai = require 'mini.ai'
        ai.setup({})
    end
}
