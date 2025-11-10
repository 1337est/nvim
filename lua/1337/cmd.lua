local augroup = vim.api.nvim_create_augroup
local autocmd = vim.api.nvim_create_autocmd

local yank_group = augroup("HighlightYank", {})
autocmd("TextYankPost", {
    desc = "Hightlight when yanking (copying) text",
    group = yank_group,
    pattern = "*",
    callback = function()
        vim.hl.on_yank({
            higroup = "IncSearch",
            timeout = 40,
        })
    end,
})

local fold_group = augroup("remember_folds", { clear = true })
autocmd({ "BufWinLeave" }, {
    group = fold_group,
    pattern = "*.*",
    command = "mkview",
})
autocmd({ "BufWinEnter" }, {
    group = fold_group,
    pattern = "*.*",
    command = "silent! loadview",
})

-- Enables wrap text for Markdown and Text files
vim.cmd([[autocmd BufEnter *.md,*.txt,*.norg set wrap]])
-- Enable spell checking for Markdown and Text files
vim.cmd([[autocmd BufEnter *.md,*.txt,*.norg set spell]])

-- Getting rid of auto-inserted comments
vim.cmd([[autocmd BufEnter * set formatoptions-=cro ]])
