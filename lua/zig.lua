local M = {}
local Batch = require("batch")
local selected_exe
local known_exes = {}

local function notify(message, level)
    vim.notify("Zig: " .. message, level or vim.log.levels.INFO)
end

local function expand(value)
    if value:sub(1, 2) == "~/" then return (vim.env.HOME or vim.fn.expand("~")) .. value:sub(2) end
    return value
end

local function resolve(exe, cwd)
    exe = expand(exe)
    if cwd and exe:find("[/\\]") and not exe:match("^/") and not exe:match("^%a:[/\\]") then
        exe = cwd .. "/" .. exe
    end
    local path = vim.fn.exepath(exe)
    if path == "" then return nil end
    path = vim.fs.normalize(vim.fn.fnamemodify(path, ":p"))
    return vim.uv.fs_realpath(path) or path
end

local function executable()
    local path = resolve(selected_exe or require("workspace").get().zig_exe)
    if not path then
        notify("Executable not found or not executable: " .. (selected_exe or require("workspace").get().zig_exe), vim.log.levels.ERROR)
        return nil
    end
    known_exes[path] = true
    return path
end

local function working_directory()
    local name = vim.api.nvim_buf_get_name(0)
    if vim.bo.buftype == "" and name ~= "" and not name:match("^%a[%w+.-]*://") then
        local stat = vim.uv.fs_stat(name)
        if not stat or stat.type ~= "directory" then return vim.fs.dirname(name) end
    end
    return vim.fn.getcwd()
end

local function zig_command(command, dir)
    local path = resolve(command.exe, dir)
    if path and known_exes[path] then return true end
    local name = vim.fs.basename(command.exe):lower()
    return name == "zig" or name == "zig.exe"
end

local function zig_run(state)
    if state.owner == "zig-info" then return false end
    if state.owner == "zig" then return true end
    for _, command in ipairs(state.commands) do
        if zig_command(command, state.cwd) then return true end
    end
    return false
end

local function new_quickfix(title)
    vim.fn.setqflist({}, " ", { nr = "$", title = title, items = {} })
    return vim.fn.getqflist({ id = 0 }).id
end

local function select_quickfix(info)
    local qf = vim.fn.getqflist({ id = info.id, nr = 0 })
    if qf.id ~= info.id then
        info.id = new_quickfix(info.title)
        vim.fn.setqflist({}, "r", { id = info.id, title = info.title, items = info.items })
        qf = vim.fn.getqflist({ id = info.id, nr = 0 })
    end
    if qf.nr > 0 then vim.cmd(("silent %dchistory"):format(qf.nr)) end
end

local function diagnostics(item)
    local lines = { "__zig_cwd__" .. item.dir }
    for _, chunks in ipairs({ item.stdout, item.stderr }) do
        local text = table.concat(chunks):gsub("\27%[[0-?]*[ -/]*[@-~]", ""):gsub("\r", "")
        vim.list_extend(lines, vim.split(text, "\n", { plain = true }))
    end
    local parsed = vim.fn.getqflist({
        lines = lines,
        efm = table.concat({
            "%D__zig_cwd__%f",
            "%f:%l:%c: %t%*[^:]: %m",
            "%f:%l:%c: %m",
            "%f:%l: %m",
            "%-G%.%#",
        }, ","),
    }).items
    return vim.tbl_filter(function(entry) return entry.valid == 1 end, parsed)
end

local function run(args, project)
    local exe = project and resolve(project.zig_exe) or executable()
    if not exe then return end
    local cwd = project and project.root or working_directory()
    local title = "zig " .. table.concat(args, " ")
    local info = { id = new_quickfix(title), title = title, items = {} }
    return Batch.run({
        exe = exe,
        args = args,
        dirs = { cwd },
        title = title,
        owner = "zig",
        on_open = function() select_quickfix(info) end,
        on_job_exit = function(item, result)
            info.items = diagnostics(item)
            local status = result and string.format("[exit %d, signal %d]", result.code, result.signal) or "[start failed]"
            info.title = title .. " " .. status
            if vim.fn.getqflist({ id = info.id }).id == info.id then
                vim.fn.setqflist({}, "r", { id = info.id, title = info.title, items = info.items })
            end
            notify(string.format("%s; %d quickfix entries", status, #info.items),
                result and result.code == 0 and result.signal == 0 and vim.log.levels.INFO or vim.log.levels.WARN)
        end,
    })
end

local function version()
    local exe = executable()
    if not exe then return end
    Batch.run({
        exe = exe,
        args = { "version" },
        dirs = { vim.fn.getcwd() },
        owner = "zig-info",
        show = false,
        on_job_exit = function(item, result)
            if not result or result.code ~= 0 or result.signal ~= 0 then
                local detail = vim.trim(table.concat(item.stderr))
                if detail == "" then detail = item.reason or "version command failed" end
                return notify(exe .. "\n" .. detail, vim.log.levels.ERROR)
            end
            local value = vim.trim(table.concat(item.stdout))
            notify("version: " .. (value ~= "" and value or "(no version output)") .. "\nexe: " .. exe)
        end,
    })
end

local function window()
    local context = Batch.context()
    local state = context and zig_run(context.state) and context.state or nil
    if not state then
        local cwd = working_directory()
        cwd = vim.uv.fs_realpath(cwd) or vim.fs.normalize(cwd)
        state = Batch.latest(function(candidate)
            if not zig_run(candidate) then return false end
            for _, item in ipairs(candidate.items) do
                if item.dir == cwd then return true end
            end
            return false
        end) or Batch.latest(zig_run)
    end
    if not state then return notify("No Zig output yet") end
    Batch.toggle(state)
end

function M.setup(opts)
    opts = opts or {}
    assert(opts.batch == nil, "Move named batches to require('batch').setup({ batches = ... })")
    assert(opts.zig_exe == nil or (type(opts.zig_exe) == "string" and opts.zig_exe ~= ""), "zig_exe must be a nonempty string")
    selected_exe = opts.zig_exe and expand(opts.zig_exe) or nil
    local resolved = selected_exe and resolve(selected_exe)
    if resolved then selected_exe = resolved; known_exes[resolved] = true end

    -- Remove the former interface when reloading this module in the same session.
    for _, name in ipairs({ "ZigOutput", "ZigBatch", "ZigBatchOutput", "ZigBatchStop" }) do
        pcall(vim.api.nvim_del_user_command, name)
    end
    vim.api.nvim_create_user_command("Zig", function(command)
        if #command.fargs == 0 then return version() end
        local args = {}
        for _, arg in ipairs(command.fargs) do args[#args + 1] = expand(arg) end
        run(args)
    end, { nargs = "*", complete = "file", desc = "Show Zig version/path, or run Zig in the current file's directory" })
    vim.api.nvim_create_user_command("ZigWindow", window, {
        desc = "Open/focus Zig output, or hide it when already focused",
    })
    vim.api.nvim_create_user_command("ZigStop", function()
        Batch.select_stop(function(entry)
            return entry.state.owner ~= "zig-info" and (entry.state.owner == "zig" or zig_command(entry.step.command, entry.item.dir))
        end, "Zig")
    end, { desc = "Interrupt Zig execution; select a job when several are running" })
    vim.api.nvim_create_user_command("ZigBuild", function(command)
        local ws = require("workspace").get()
        local args = { "build" }
        vim.list_extend(args, command.fargs)
        for _, value in ipairs(ws.build_options) do args[#args + 1] = "-D" .. value end
        run(args, ws)
    end, { nargs = "*", complete = "file", desc = "Run zig build [steps] in workspace root with workspace options" })
    vim.api.nvim_create_user_command("ZigExe", function(command)
        if #command.fargs == 0 then
            selected_exe = nil; notify("Command override cleared; using workspace toolchain"); return
        end
        local path = resolve(command.fargs[1])
        if not path then return notify("Executable not found or not executable: " .. command.fargs[1], vim.log.levels.ERROR) end
        selected_exe, known_exes[path] = path, true
        notify("exe: " .. path)
    end, { nargs = "?", complete = "file", desc = "Override :Zig compiler only; no args restores workspace compiler" })
end

return M
