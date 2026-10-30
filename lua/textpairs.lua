local M = {}

local textpairs = {
    ["("] = ")",
    ["["] = "]",
    ["{"] = "}",
    ['"'] = '"',
    ["'"] = "'",
    ["`"] = "`",
}

local function next_char()
    local line = vim.api.nvim_get_current_line()
    local col = vim.api.nvim_win_get_cursor(0)[2]
    return line:sub(col + 1, col + 1)
end

function M.setup()
    for open, close in pairs(textpairs) do
        vim.keymap.set("i", open, function()
            if open == close and next_char() == close then
                return "<Right>"
            end
            return open .. close .. "<Left>"
        end, { expr = true })

        if open ~= close then
            vim.keymap.set("i", close, function()
                return next_char() == close and "<Right>" or close
            end, { expr = true })
        end
    end

    vim.keymap.set("i", "<BS>", function()
        local line = vim.api.nvim_get_current_line()
        local col = vim.api.nvim_win_get_cursor(0)[2]
        return textpairs[line:sub(col, col)] == line:sub(col + 1, col + 1)
            and "<Del><BS>" or "<BS>"
    end, { expr = true })
end

return M
