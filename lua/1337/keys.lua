-- Preserves text instead of replacing the register with the deleted text by
-- deleting text into the 'blackhole' register "_d.
vim.keymap.set("v", "<leader>kp", [["_dP]], { desc = "[k]eep [p]aste" })
vim.keymap.set({ "n", "v" }, "<leader>kd", [["_d]], { desc = "[k]eep [d]elete" })

-- Set highlight on search, but clear on pressing <Esc> in normal mode
vim.keymap.set("n", "<Esc>", "<cmd>nohlsearch<CR>")

-- Diagnostic keymaps
vim.keymap.set("n", "[d", vim.diagnostic.goto_prev, { desc = "Previous [d]iagnostic" })
vim.keymap.set("n", "]d", vim.diagnostic.goto_next, { desc = "Next [d]iagnostic" })
vim.keymap.set("n", "<leader>e", vim.diagnostic.open_float,
    { desc = "Show diagnostic [e]rror messages" })
vim.keymap.set("n", "<leader>q", vim.diagnostic.setloclist,
    { desc = "Open diagnostic [q]uickfix list" })

-- Manual auto-formatting
vim.keymap.set("n", "<leader>f", function()
    local save_cursor = vim.fn.getcurpos()
    vim.cmd("normal gg=G")
    vim.fn.setpos('.', save_cursor)
end, { desc = "[f]ormat File" })
