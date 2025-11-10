-- keymaps to call telescope functions
local telebuilt = require("telescope.builtin")
local map = function(keys, func, desc)
    vim.keymap.set("n", keys, func,
        { desc = "TEL: " .. desc })
end

map("<leader>sh", telebuilt.help_tags, "[s]earch [h]elp")
map("<leader>sk", telebuilt.keymaps, "[s]earch [k]eymaps")
map("<leader>sf", telebuilt.find_files, "[s]earch [f]iles")
map("<leader>ss", telebuilt.builtin, "[s]earch [s]elect Telescope")
map("<leader>sw", telebuilt.grep_string, "[s]earch current [w]ord")
map("<leader>sg", telebuilt.live_grep, "[s]earch by [g]rep")
map("<leader>sd", telebuilt.diagnostics, "[s]earch [d]iagnostics")
map("<leader>sr", telebuilt.resume, "[s]earch [r]esume")
map("<leader>s.", telebuilt.oldfiles, '[s]earch Recent Files ("." for repeat)')
map("<leader><leader>", telebuilt.buffers, "[ ] Find existing buffers")

-- Search in current buffer
map("<leader>/", function()
    -- You can pass additional configuration to Telescope to change the theme, layout, etc.
    telebuilt.current_buffer_fuzzy_find(require("telescope.themes").get_dropdown({
        winblend = 10,
        previewer = false,
    }))
end, "[/] Fuzzily search in current buffer")

-- Search open files
map("<leader>s/", function()
    telebuilt.live_grep({
        grep_open_files = true,
        prompt_title = "Live Grep in Open Files",
    })
end, "[s]earch [/] in Open Files")

-- Shortcut for searching your Neovim configuration files
map("<leader>sn", function()
    telebuilt.find_files({ cwd = vim.fn.stdpath("config") })
end, "[s]earch [n]eovim files")

-- Shortcut for searching your Neorg notes
map("<leader>sN", function()
    telebuilt.find_files({ cwd = vim.fs.abspath("~/Desktop/notes") })
end, "[s]earch [n]eovim files")
