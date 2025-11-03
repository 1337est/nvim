vim.api.nvim_create_autocmd("Filetype", {
    desc = "Settings for when a .norg file is opened.",
    pattern = "norg",
    callback = function()
        -- Ensures the module is reloaded to apply keymaps to new buffers
        package.loaded["custom.neorg.keys"] = nil
        require("custom.neorg.keys")
        -- any other .norg specific options go here
    end,
})
