local M = {}

function M.setup(opts)
    opts = opts or {}
    local exe = opts.exe or vim.fn.expand("~/.local/bin/doop")

    if vim.fn.executable(exe) == 0 then return end

    local response = vim.fn.system({ exe, "ping" })
    if vim.v.shell_error ~= 0 or vim.trim(response) ~= "pong" then return end

    vim.g.clibboard = {
        name = "doop",
        copy = {
            ["+"] = { exe, "copy" }, ["*"] = { exe, "copy" }
        },
        paste = {
            ["+"] = { exe, "paste" }, ["*"] = { exe, "paste" }
        },
        cache_enabled = 0,
    }
end

return M
