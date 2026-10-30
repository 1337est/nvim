local M = {}

function M.setup()
    vim.cmd("packadd! termdebug")

    local function map(key, command, description)
        vim.keymap.set("n", key, "<cmd>" .. command .. "<CR>", {
            silent = true,
            desc = "Debugger: " .. description,
        })
    end

    map("<leader>db", "Break", "set breakpoint")
    map("<leader>dc", "Continue", "continue execution")
    map("<leader>ds", "Step", "step into")
    map("<leader>dn", "Over", "step over")
    map("<leader>df", "Finish", "finish function")
    map("<leader>dv", "Var", "inspect variable")
    map("<leader>da", "Asm", "show assembly")
end

return M
