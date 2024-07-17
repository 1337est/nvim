-- Colors the matching paren pairs
vim.api.nvim_command([[ highlight MatchParen guibg=#0030F0 ]])

-- Enables wrap text for Markdown and Text files
vim.cmd([[autocmd BufEnter *.md,*.txt set wrap]])
-- Enable spell checking for Markdown and Text files
vim.cmd([[autocmd BufEnter *.md,*.txt set spell]])
-- Enable visual column soft-wrap
vim.cmd([[autocmd BufEnter *.md,*.txt set columns=100]])

-- Highlight when yanking (copying) text
--  Try it with `yap` in normal mode
--  See `:help vim.highlight.on_yank()`
vim.api.nvim_create_autocmd("TextYankPost", {
	desc = "Highlight when yanking (copying) text",
	group = vim.api.nvim_create_augroup("kickstart-highlight-yank", { clear = true }),
	callback = function()
		vim.highlight.on_yank()
	end,
})

-- Getting rid of auto-inserted comments
vim.cmd([[autocmd BufEnter * set formatoptions-=cro ]])
