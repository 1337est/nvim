local M = {}

local config = {
    header = { name = "floaterminal", pos = "left" },
    footer = { name = "1337est", pos = "right" },
}

local state = {
    floating = {
        buf = -1,
        win = -1,
    }
}

-- BUG: When creating a floating window and on a separate tab
-- the floating window should be attached to that tab. Right now there
-- can only be 1 floating window at a time, meaning when toggle_terminal()
-- is ran, it toggles the terminal in the current tab, then switching to
-- a different tab while the floating terminal is still on the previous tab
-- and using toggle_terminal() on the new tab, the previous tab's floating
-- terminal closes. Then invoking toggle_terminal again correctly opens
-- the floating terminal in the current tab. This means there can only be
-- 1 floating terminal at a time, when there should be a floating terminal
-- allowed per tab. For now, each tab should have their own dedicated floating
-- terminal. I'll add many terminals per tab when I need it.
local function create_floating_window(opts)
    opts = opts or {}
    local width = opts.width or math.floor(vim.o.columns * 0.8)
    local height = opts.height or math.floor(vim.o.lines * 0.8)

    local col = math.floor((vim.o.columns - width) / 2)
    local row = math.floor((vim.o.lines - height) / 2)

    local buf = nil
    if vim.api.nvim_buf_is_valid(opts.buf) then
        buf = opts.buf
    else
        buf = vim.api.nvim_create_buf(false, true)
    end

    local win = vim.api.nvim_open_win(buf, true, {
        relative = "editor",
        width = width,
        height = height,
        col = col,
        row = row,
        style = "minimal",
        border = "bold",
        title = config.header.name,
        title_pos = config.header.pos,
        footer = config.footer.name,
        footer_pos = config.footer.pos,
    })

    return { buf = buf, win = win }
end

local function toggle_terminal()
    if not vim.api.nvim_win_is_valid(state.floating.win) then
        state.floating = create_floating_window { buf = state.floating.buf }
        if vim.bo[state.floating.buf].buftype ~= "terminal" then
            vim.cmd.term()
            state.floating.buf = vim.api.nvim_get_current_buf()
        end
    else
        vim.api.nvim_win_hide(state.floating.win)
    end
end

function M.setup(opts)
    config = vim.tbl_deep_extend("force", config, opts or {})

    vim.api.nvim_create_user_command("Floaterminal", toggle_terminal, {})

    vim.keymap.set({ "n", "t" }, "<leader>tt", toggle_terminal, {
        desc = "1337: toggle terminal",
    })

    vim.keymap.set("t", "<esc><esc>", "<c-\\><c-n>", {
        desc = "1337: normal mode",
    })
end

return M
