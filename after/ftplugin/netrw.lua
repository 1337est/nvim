local function map(mode, key, map, description)
    vim.keymap.set(mode, key, map, {
        buffer = true,
        remap = true,
        silent = true,
        desc = "Explorer: " .. description,
    })
end

map("n", "<leader>e", "-", "go up dir")
map("n", "<leader>gh", "gh", "toggle .files")
map("n", "<leader>%", "%", "create file")
map("n", "<leader>d", "d", "create directory")
map("n", "<leader>R", "R", "rename file/directory")
map("n", "<leader>D", "D", "delete file/directory")
