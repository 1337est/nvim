local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
    local lazyrepo = "https://github.com/folke/lazy.nvim.git"
    local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
    if vim.v.shell_error ~= 0 then
        vim.api.nvim_echo({
            { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
            { out, "WarningMsg" },
            { "\nPress any key to exit..." },
        }, true, {})
        vim.fn.getchar()
        os.exit(1)
    end
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
    spec = {
        {
            import = "plugins.lazy.install",
        },
    },
    -- try to load one of these colorschemes
    install = { colorscheme = { "monokai-pro", "habamax" } },

    -- lockfile is where all other lazy stuff is
    lockfile = vim.fn.stdpath("config") .. "/lua/plugins/lazy/lazy-lock.json",

    ui = {
        -- The border to use for the UI window. Accepts same border values as |nvim_open_win()|.
        border = "bold",
        title = "lazy.nvim",
        title_pos = "left",
        custom_keys = { -- To disable one of the defaults, set it to false
            ["<localleader>l"] = {
                function(plugin)
                    require("lazy.util").float_term({ "lazygit", "log" }, {
                        cwd = plugin.dir,
                    })
                end,
                desc = "Open lazygit log",
            },

            ["<localleader>i"] = {
                function(plugin)
                    Util.notify(vim.inspect(plugin), {
                        title = "Inspect " .. plugin.name,
                        lang = "lua",
                    })
                end,
                desc = "Inspect Plugin",
            },

            ["<localleader>t"] = {
                function(plugin)
                    require("lazy.util").float_term(nil, {
                        cwd = plugin.dir,
                    })
                end,
                desc = "Open terminal in plugin dir",
            },
        },
    },
    -- stop annoying "this file has been updated notifications"
    change_detection = { enabled = true, notify = false },
})
