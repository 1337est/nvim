--[[ Default keymaps --]]
local dmap = function(mode, keys, func, desc)
    vim.keymap.set(mode, keys, "<Plug>(neorg." .. func .. ")",
        { buffer = true, desc = "neorg: " .. desc })
end

-- task/todo manipulations
dmap("n", "<C-Space>", "qol.todo-items.todo.task-cycle", "Task cycle")
dmap("n", "<leader>ta", "qol.todo-items.todo.task-ambiguous", "[t]oggle [a]mbiguous")
dmap("n", "<leader>tc", "qol.todo-items.todo.task-cancelled", "[t]ask [c]ancelled")
dmap("n", "<leader>td", "qol.todo-items.todo.task-done", "[t]ask [d]one")
dmap("n", "<leader>th", "qol.todo-items.todo.task-on-hold", "[t]ask on [h]old")
dmap("n", "<leader>ti", "qol.todo-items.todo.task-important", "[t]ask [i]mportant")
dmap("n", "<leader>tp", "qol.todo-items.todo.task-pending", "[t]ask [p]ending")
dmap("n", "<leader>tr", "qol.todo-items.todo.task-recurring", "[t]ask [r]ecurring")
dmap("n", "<leader>tu", "qol.todo-items.todo.task-undone", "[t]ask [u]ndone")
-- list converting/toggling
dmap("n", "<leader>li", "pivot.list.invert", "[l]ist [i]nvert")
dmap("n", "<leader>lt", "pivot.list.toggle", "[l]ist [t]oggle")

-- link hopping
dmap("n", "<CR>", "esupports.hop.hop-link", "Open link")
dmap("n", "<M-CR>", "esupports.hop.hop-link.vsplit", "Open link vsplit")
dmap("n", "<M-t>", "esupports.hop.hop-link.tab-drop", "Open link new [t]ab")
-- inserting date links
dmap("i", "<M-d>", "tempus.insert-date.insert-mode", "insert [d]ate")
dmap("n", "<leader>id", "tempus.insert-date", "insert [d]ate")

-- heirarchy demotion
dmap("i", "<C-d>", "promo.demote", "[d]emote single")
dmap("n", "<,", "promo.demote", "[d]emote single")
dmap("n", "<<", "promo.demote.nested", "[d]emote nested")
dmap("v", "<", "promo.demote.range", "[d]emote range")
-- heirarchy promotion
dmap("i", "<C-t>", "promo.promote", "[p]romote single")
dmap("n", ">.", "promo.promote", "[p]romote single")
dmap("n", ">>", "promo.promote.nested", "[p]romote nested")
dmap("v", ">", "promo.promote.range", "[p]romote range")

-- Continue the neorg indentation schema on next line
dmap("i", "<M-CR>", "itero.next-iteration", "Cont. Schema")
-- open code tag in a temporary buffer
dmap("n", "<leader>mc", "looking-glass.magnify-code-block", "[m]agnify code")

--[[ Custom keymaps --]]
local cmap = function(keys, func, desc)
    vim.keymap.set("n", keys, func,
        { buffer = true, silent = true, desc = "neorg: " .. desc })
end

-- Toggle the neorg concealer
cmap("<leader>tm", function()
    vim.cmd.Neorg("toggle-concealer")
end, "[t]oggle [m]arkup")
