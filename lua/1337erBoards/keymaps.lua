-----------------------------------------------------------------------------------------------------------------------
-- Personal settings
-----------------------------------------------------------------------------------------------------------------------
-- From ThePrimeagen: performs actions while deleting the text into the
-- 'blackhole' register "_d. This preserves text instead of replacing
-- the register with the deleted text.
vim.keymap.set("v", "<leader>kp", [["_dP]], { desc = "[k]eep current, [p]aste" })
vim.keymap.set({ "n", "v" }, "<leader>kd", [["_d]], { desc = "[k]eep current, [d]elete" })

-- Set highlight on search, but clear on pressing <Esc> in normal mode
vim.keymap.set("n", "<Esc>", "<cmd>nohlsearch<CR>")

-- Diagnostic keymaps
vim.keymap.set("n", "[d", vim.diagnostic.goto_prev, { desc = "Go to previous [D]iagnostic message" })
vim.keymap.set("n", "]d", vim.diagnostic.goto_next, { desc = "Go to next [D]iagnostic message" })
vim.keymap.set("n", "<leader>e", vim.diagnostic.open_float, { desc = "Show diagnostic [E]rror messages" })
vim.keymap.set("n", "<leader>q", vim.diagnostic.setloclist, { desc = "Open diagnostic [Q]uickfix list" })

-- Exit terminal mode in the builtin terminal with a shortcut that is a bit easier
-- for people to discover. Otherwise, you normally need to press <C-\><C-n>, which
-- is not what someone will guess without a bit more experience.
--
-- NOTE: This won't work in all terminal emulators/tmux/etc. Try your own mapping
-- or just use <C-\><C-n> to exit terminal mode
vim.keymap.set("t", "<Esc><Esc>", "<C-\\><C-n>", { desc = "Exit terminal mode" })

-----------------------------------------------------------------------------------------------------------------------
-- Telescope keymaps
-----------------------------------------------------------------------------------------------------------------------
-- local telescope = require('telescope.builtin')
-- -- search for files
-- vim.keymap.set('n', '<leader>sf', telescope.find_files, { desc = '[S]earch for [f]iles' })
-- -- search for git files
-- vim.keymap.set('n', '<leader>sg', telescope.git_files, { desc = '[S]earch for [g]it [f]iles' })
-- -- search for string
-- vim.keymap.set('n', '<leader>ss', function()
--     telescope.grep_string({ search = vim.fn.input("Grep > ") })
-- end, { desc = '[S]earch for [s]tring' })
-- -- search help
-- vim.keymap.set('n', '<leader>sh', telescope.help_tags, { desc = '[S]earch [h]elp tags'})
