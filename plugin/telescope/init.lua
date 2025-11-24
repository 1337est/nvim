local utils = require("utils")
local map = utils.map

local ok_telescope, telescope = pcall(require, "telescope")
if ok_telescope then
    telescope.setup {
        extensions = { ["ui-select"] = require("telescope.themes").get_dropdown(), },
        pickers = { find_files = { hidden = true, no_ignore = true, no_ignore_parent = true }, },
        defaults = { file_ignore_patterns = { "undodir", "node_modules" }, },
    }
end

local ok_tel, tel = pcall(require, 'telescope.builtin')
if ok_tel then
    map({ mode = "n", keys = "<leader>st", owner = "TEL", desc = "telescope builtins", fn = tel.builtin })

    map({ mode = "n", keys = "<leader>sk", owner = "TEL", desc = "search nvim keymaps", fn = tel.keymaps })
    map({ mode = "n", keys = "<leader>sh", owner = "TEL", desc = "search nvim help_tags", fn = tel.help_tags })

    map({ mode = "n", keys = "<leader>sf", owner = "TEL", desc = "search file by name from cwd", fn = tel.find_files })
    map({ mode = "n", keys = "<leader>so", owner = "TEL", desc = "search file by name from file history", fn = tel.oldfiles })
    map({ mode = "n", keys = "<leader>sb", owner = "TEL", desc = "Find existing buffers", fn = tel.buffers })

    map({ mode = "n", keys = "<leader>s/", owner = "TEL", desc = "search word with dynamic grep", fn = tel.live_grep })

    map({ mode = "n", keys = "<leader>sd", owner = "TEL", desc = "search diagnostics list", fn = tel.diagnostics })
end
