-- Finite build/metadata commands. Daemon lifecycle stays in the generated zwe.lua.
local M = {}
local settings = {}
local building = false
function M.executable()
    return settings.cmd or (vim.fn.stdpath("data") .. "/zwe/current/zwe")
end
local function notify(text, level)
    vim.notify(text, level or vim.log.levels.INFO, { title = "ZWE" })
end
function M.build()
    if building then return notify("A ZWE installation is already running.", vim.log.levels.WARN) end
    local compiler = settings.zig_exe or "zig"
    if vim.fn.executable(compiler) ~= 1 then return notify("Compiler not executable: " .. compiler, vim.log.levels.ERROR) end
    building = true
    local ok, value = pcall(require("batch").run, {
        exe = "bash",
        args = { vim.fn.stdpath("config") .. "/scripts/install-zwe.sh", "--zig", compiler,
            "--data", vim.fn.stdpath("data") .. "/zwe", "--cache", vim.fn.stdpath("cache") .. "/zwe",
            "--cpu", settings.cpu or "baseline" },
        dirs = { vim.fn.stdpath("config") }, title = "Build and install ZWE", owner = "zwe-build", concurrency = 1,
        on_complete = function(state)
            building = false
            local item = state.items[1]
            if item and item.status == "succeeded" then
                local client = package.loaded.zwe
                if client then client.stop(true) end
                notify("ZWE installed. Reopen Neovim before restarting it so the generated client matches the executable.")
            else notify("ZWE installation failed; previous installation was retained. Inspect :BatchOutput.", vim.log.levels.ERROR) end
        end,
    })
    if not ok then building = false; notify(tostring(value), vim.log.levels.ERROR) end
    return ok and value or nil
end
-- JSON paths in, parsed ZON metadata out. No build script execution or daemon required.
function M.manifests(paths, callback)
    assert(type(paths) == "table" and vim.islist(paths), "paths must be an array")
    assert(type(callback) == "function", "callback required")
    local exe = M.executable()
    if vim.fn.executable(exe) ~= 1 then callback("Build ZWE first with :ZweBuild"); return end
    if #paths > 4096 then callback("Too many manifests (maximum 4096)"); return end
    local resolved = {}
    for _, path in ipairs(paths) do
        assert(type(path) == "string" and not path:find("%z"), "manifest paths must be strings without NUL")
        if path:sub(1, 2) == "~/" then path = (vim.env.HOME or vim.fn.expand("~")) .. path:sub(2) end
        resolved[#resolved + 1] = vim.fs.normalize(vim.fn.fnamemodify(path, ":p"))
    end
    local ok, job = pcall(vim.system, { exe, "manifests" }, { text = true, stdin = vim.json.encode(resolved) }, function(result)
        vim.schedule(function()
            if result.code ~= 0 then callback(result.stderr ~= "" and result.stderr or "Manifest parsing failed"); return end
            local parsed, data = pcall(vim.json.decode, result.stdout)
            if not parsed then callback("Invalid manifest response: " .. tostring(data)); return end
            if type(data) ~= "table" or type(data.projects) ~= "table" or type(data.errors) ~= "table" then callback("Invalid manifest response schema"); return end
            callback(nil, data)
        end)
    end)
    if not ok then callback(tostring(job)); return end
    return job
end
function M.setup(opts)
    settings = opts or {}
    vim.api.nvim_create_user_command("ZweBuild", M.build, { desc = "Test, build, and explicitly install a matching ZWE/client pair" })
    vim.api.nvim_create_user_command("ZweManifests", function(command)
        local paths = command.fargs
        if #paths == 0 then paths = { require("workspace").get().root .. "/build.zig.zon" } end
        M.manifests(paths, function(err, data)
            if err then return notify(err, vim.log.levels.ERROR) end
            local buf = vim.api.nvim_create_buf(false, true)
            vim.bo[buf].bufhidden, vim.bo[buf].filetype = "wipe", "lua"
            vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(vim.inspect(data), "\n", { plain = true }))
            vim.bo[buf].modifiable = false
            vim.cmd("botright 12split")
            vim.api.nvim_win_set_buf(0, buf)
            vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = buf, silent = true })
        end)
    end, { nargs = "*", complete = "file", desc = "Read manifest metadata without executing build.zig" })
end
return M
