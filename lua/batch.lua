local M = {}

local configured = {}
local runs = {}
local contexts = {}
local serial = 0
local catalog_buf
local output_win
local options = { concurrency = 4, max_output_bytes = 2 * 1024 * 1024, max_history = 20 }
local pump

local function visible(buf)
    return buf and vim.api.nvim_buf_is_loaded(buf) and #vim.fn.win_findbuf(buf) > 0
end

-- Retain a bounded tail without rebuilding the entire log on every output callback.
local function append_output(holder, channel_name, data, limit)
    if not data or data == "" then return end
    local chunks = holder[channel_name]
    local key = channel_name .. "_bytes"
    chunks[#chunks + 1] = data
    holder[key] = (holder[key] or 0) + #data
    while holder[key] > limit and #chunks > 0 do
        local excess = holder[key] - limit
        if #chunks[1] <= excess then holder[key] = holder[key] - #table.remove(chunks, 1)
        else chunks[1] = chunks[1]:sub(excess + 1); holder[key] = limit end
        holder.truncated = true
    end
end

local function prune_history()
    local i = 1
    while #runs > options.max_history and i <= #runs do
        local state = runs[i]
        local shown = visible(state.buf)
        for _, item in ipairs(state.items) do shown = shown or visible(item.buf) end
        if state.finished and not shown then
            local function remove(buf)
                if buf then contexts[buf] = nil; pcall(vim.api.nvim_buf_delete, buf, { force = true }) end
            end
            remove(state.buf)
            for _, item in ipairs(state.items) do remove(item.buf) end
            table.remove(runs, i)
        else i = i + 1 end
    end
end

local function notify(message, level)
    vim.notify("Batch: " .. message, level or vim.log.levels.INFO)
end

local function callback(fn, ...)
    if not fn then return end
    local ok, err = pcall(fn, ...)
    if not ok then notify(tostring(err), vim.log.levels.ERROR) end
end

local function expand(path)
    if path == "~" then return vim.env.HOME or vim.fn.expand("~") end
    if path:sub(1, 2) == "~/" then
        return (vim.env.HOME or vim.fn.expand("~")) .. path:sub(2)
    end
    return path
end

local function directory(path)
    local value = vim.fs.normalize(vim.fn.fnamemodify(expand(path), ":p"))
    return vim.uv.fs_realpath(value) or value
end

local function one_line(value)
    return tostring(value):gsub("\r", "\\r"):gsub("\n", "\\n"):gsub("%z", "^@")
end

local function command_string(argv)
    return one_line(table.concat(vim.tbl_map(vim.fn.shellescape, argv), " "))
end

local function elapsed(started, ended)
    if not started then return "00:00:000000" end
    local us = math.floor(((ended or vim.uv.hrtime()) - started) / 1000)
    return string.format("%02d:%02d:%06d", math.floor(us / 60000000), math.floor(us / 1000000) % 60, us % 1000000)
end

local function clean(value)
    return value:gsub("\27%[[0-?]*[ -/]*[@-~]", ""):gsub("\r", ""):gsub("%z", "^@")
end

local function channel(lines, label, chunks)
    local content = clean(table.concat(chunks))
    local parts = vim.split(content, "\n", { plain = true })
    if #parts > 1 and parts[#parts] == "" then table.remove(parts) end
    lines[#lines + 1] = label .. ":" .. (content ~= "" and (" " .. parts[1]) or "")
    for i = 2, #parts do lines[#lines + 1] = parts[i] end
end

local function counts(state)
    local result = { ready = 0, running = 0, succeeded = 0, failed = 0, skipped = 0, stopped = 0 }
    for _, item in ipairs(state.items) do result[item.status] = result[item.status] + 1 end
    return result
end

local function put_lines(buf, lines)
    if not buf or not vim.api.nvim_buf_is_loaded(buf) then return end
    vim.bo[buf].modifiable = true
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].modifiable = false
    vim.bo[buf].modified = false
end

local function reusable(buf)
    if not buf or not vim.api.nvim_buf_is_valid(buf) then return false end
    if not vim.api.nvim_buf_is_loaded(buf) then vim.fn.bufload(buf) end
    return true
end

local function hide_window(win)
    local ok = pcall(vim.api.nvim_win_hide, win)
    if not ok and vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_win_set_buf(win, vim.api.nvim_create_buf(true, false))
    end
end

local function hide(buf)
    for _, win in ipairs(vim.api.nvim_list_wins()) do
        if vim.api.nvim_win_get_buf(win) == buf then
            hide_window(win)
        end
    end
end

local function scratch(name, context)
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(buf, name)
    vim.bo[buf].bufhidden = "hide"
    vim.bo[buf].filetype = "batchoutput"
    vim.bo[buf].swapfile = false
    contexts[buf] = context
    vim.keymap.set("n", "q", function() hide(buf) end, { buffer = buf, silent = true, desc = "Batch: hide output" })
    return buf
end

local function show(buf, toggle)
    local win = vim.fn.bufwinid(buf)
    if win ~= -1 then
        if toggle and win == vim.api.nvim_get_current_win() then
            hide_window(win)
        else
            vim.api.nvim_set_current_win(win)
        end
    else
        local reuse = output_win and vim.api.nvim_win_is_valid(output_win)
            and vim.api.nvim_win_get_tabpage(output_win) == vim.api.nvim_get_current_tabpage()
        local previous = reuse and vim.api.nvim_win_get_buf(output_win)
        if reuse and (contexts[previous] or previous == catalog_buf) then
            vim.api.nvim_set_current_win(output_win)
        else
            vim.cmd("botright 12split")
        end
        vim.api.nvim_win_set_buf(0, buf)
    end
    local visible = vim.fn.bufwinid(buf)
    if visible ~= -1 then output_win = visible end
end

function M.context()
    return contexts[vim.api.nvim_get_current_buf()]
end

function M.latest(predicate)
    for i = #runs, 1, -1 do
        local state = runs[i]
        if not state.hidden and (not predicate or predicate(state)) then return state end
    end
end

local function render_output(state, item, force)
    if not item.buf or not vim.api.nvim_buf_is_loaded(item.buf) then return end
    if not force and (not item.dirty or not visible(item.buf)) then return end
    item.dirty = false
    local lines = { "cwd: " .. one_line(item.dir) }
    if item.truncated then lines[#lines + 1] = "[output tail truncated at configured limit]" end
    if item.log_paths then lines[#lines + 1] = "Full logs: " .. one_line(item.log_paths.stdout) .. " / " .. one_line(item.log_paths.stderr) end
    if #item.steps > 1 then lines[#lines + 1] = "batch: " .. state.title end
    for i, step in ipairs(item.steps) do
        if i > 1 then lines[#lines + 1] = "" end
        local label = #item.steps == 1 and "cmd" or ("cmd" .. i)
        lines[#lines + 1] = label .. ": " .. step.command.text
        channel(lines, "out", step.stdout)
        channel(lines, "err", step.stderr)
        if step.status == "running" then
            lines[#lines + 1] = "[running] [" .. elapsed(step.started_at) .. "]"
        elseif step.result then
            lines[#lines + 1] = string.format("[exit %d, signal %d] [%s]", step.result.code, step.result.signal,
                elapsed(step.started_at, step.ended_at))
        else
            lines[#lines + 1] = "[" .. step.status .. "]"
        end
        if step.reason then lines[#lines + 1] = one_line(step.reason) end
    end
    if item.reason then lines[#lines + 1] = one_line(item.reason) end
    if #item.steps > 1 then
        lines[#lines + 1] = "sequence: [" .. item.status .. "] [" .. elapsed(item.started_at, item.ended_at) .. "]"
    end
    put_lines(item.buf, lines)
end

local function render_summary(state)
    if not state.buf or not vim.api.nvim_buf_is_loaded(state.buf) then return end
    local n = counts(state)
    local lines = { "Batch: " .. state.title .. " [" .. state.phase .. "]" }
    if state.phase == "preview" then lines[#lines + 1] = "cwd: " .. one_line(state.cwd) end
    for i, command in ipairs(state.commands) do
        local label = #state.commands == 1 and "cmd" or ("cmd" .. i)
        lines[#lines + 1] = label .. ": " .. command.text
    end
    lines[#lines + 1] = string.format("%d ready; %d running; %d succeeded; %d failed; %d skipped; %d stopped",
        n.ready, n.running, n.succeeded, n.failed, n.skipped, n.stopped)
    lines[#lines + 1] = "Enter on a started directory opens its output. :BatchStop interrupts running jobs."
    lines[#lines + 1] = ""
    state.rows = {}
    for _, item in ipairs(state.items) do
        local function row(text)
            lines[#lines + 1] = text
            state.rows[#lines] = item
        end
        row("[" .. item.status .. "] " .. one_line(item.dir))
        if item.reason then row("    " .. one_line(item.reason)) end
        if item.status == "running" then
            row("    " .. elapsed(item.started_at))
            if #item.steps > 1 then row(string.format("    command %d/%d", item.index, #item.steps)) end
        elseif item.result then
            row(string.format("    exit %d, signal %d, %s", item.result.code, item.result.signal,
                elapsed(item.started_at, item.ended_at)))
        elseif state.phase ~= "preview" then
            row("    not executed, " .. elapsed(item.started_at, item.ended_at))
        end
    end
    put_lines(state.buf, lines)
end

local function output_buffer(state, item)
    if not reusable(item.buf) then
        item.buf = scratch("batch://output/" .. state.id .. "/" .. item.id, { state = state, item = item })
    end
    render_output(state, item, true)
    return item.buf
end

local function summary_buffer(state)
    if not reusable(state.buf) then
        state.buf = scratch("batch://summary/" .. state.id, { state = state })
        vim.keymap.set("n", "<CR>", function()
            local item = state.rows[vim.api.nvim_win_get_cursor(0)[1]]
            if item and item.started_at then
                M.open_job(state, item.dir)
            elseif item then
                notify("No output for this directory")
            end
        end, { buffer = state.buf, silent = true, desc = "Batch: open directory output" })
    end
    render_summary(state)
    return state.buf
end

function M.open_summary(state, toggle)
    state = state or M.latest()
    if not state then return notify("No batch output yet") end
    show(summary_buffer(state), toggle)
end

function M.open_job(state, dir, toggle)
    state = state or M.latest()
    if not state then return notify("No batch output yet") end
    dir = directory(dir)
    for _, item in ipairs(state.items) do
        if item.dir == dir then
            if not item.started_at then return notify("No output for this directory") end
            show(output_buffer(state, item), toggle)
            callback(state.on_open, item, state)
            return
        end
    end
    notify("Directory is not in this batch: " .. dir, vim.log.levels.WARN)
end

function M.open(state, toggle)
    state = state or M.latest()
    if not state then return notify("No batch output yet") end
    local context = M.context()
    if context and context.state == state and context.item then
        return M.open_job(state, context.item.dir, toggle)
    end
    if not state.summary_only and #state.items == 1 and state.items[1].started_at then
        return M.open_job(state, state.items[1].dir, toggle)
    end
    M.open_summary(state, toggle)
end

function M.toggle(state)
    M.open(state, true)
end

local function finish(state)
    if state.finished or state.launching then return end
    local n = counts(state)
    if n.ready > 0 or n.running > 0 then return end
    state.finished, state.running = true, false
    state.phase = (state.cancelled or n.stopped > 0) and "stopped" or "complete"
    if state.timer then
        vim.fn.timer_stop(state.timer)
        state.timer = nil
    end
    render_summary(state)
    callback(state.on_complete, state)
    prune_history()
end

local function remaining(item, status, reason)
    for _, step in ipairs(item.steps) do
        if step.status == "pending" then step.status, step.reason = status, reason end
    end
end

local function complete_item(state, item, status, reason)
    if item.done then return end
    item.done, item.status, item.reason = true, status, reason
    item.dirty = true
    for _, fd in pairs(item.log_fds or {}) do pcall(vim.uv.fs_close, fd) end
    item.log_fds = nil
    item.ended_at = vim.uv.hrtime()
    item.active, item.job = nil, nil
    if status ~= "succeeded" then remaining(item, status == "stopped" and "stopped" or "skipped", reason) end
    render_output(state, item)
    render_summary(state)
    callback(state.on_job_exit, item, item.result, state)
    vim.schedule(function() if state.running then pump(state) end end)
    finish(state)
end

local function start_step(state, item)
    if item.done then return end
    if state.cancelled or item.stop_requested then
        return complete_item(state, item, "stopped", "Remaining commands were not started")
    end
    item.index = item.index + 1
    local step = item.steps[item.index]
    if not step then return complete_item(state, item, "succeeded") end

    item.status, step.status = "running", "running"
    item.dirty = true
    step.started_at = vim.uv.hrtime()
    item.started_at = item.started_at or step.started_at
    item.active = step
    if state.log_dir and not item.log_paths then
        local directory_path = state.log_dir .. "/" .. state.id .. "-" .. item.id .. "-" .. tostring(vim.uv.hrtime())
        vim.fn.mkdir(directory_path, "p", 448)
        item.log_paths, item.log_fds = {}, {}
        for _, name in ipairs({ "stdout", "stderr" }) do
            local path = directory_path .. "/" .. name .. ".log"
            local fd, err = vim.uv.fs_open(path, "w", 384)
            if fd then item.log_paths[name], item.log_fds[name] = path, fd
            else item.log_paths[name] = "(unavailable)"; notify(tostring(err), vim.log.levels.WARN) end
        end
    end
    local function add(channel_name, data)
        append_output(step, channel_name, data, state.max_output_bytes)
        append_output(item, channel_name, data, state.max_output_bytes)
        local fd = item.log_fds and item.log_fds[channel_name]
        if fd and data then
            local written, err = vim.uv.fs_write(fd, data, -1)
            if not written or written ~= #data then
                vim.uv.fs_close(fd); item.log_fds[channel_name] = nil
                vim.schedule(function() notify("Log write failed: " .. tostring(err or "short write"), vim.log.levels.WARN) end)
            end
        end
        item.dirty = true
    end
    local function stream(channel_name)
        return function(err, data)
            if err then add("stderr", tostring(err) .. "\n") end
            if data and data ~= "" then add(channel_name, data) end
        end
    end

    local ok, job = pcall(vim.system, step.command.argv, {
        cwd = item.dir,
        text = true,
        env = { NO_COLOR = "1", CLICOLOR_FORCE = "0" },
        stdout = stream("stdout"),
        stderr = stream("stderr"),
    }, function(result)
        local ended_at = vim.uv.hrtime()
        vim.schedule(function()
            if step.completed then return end
            step.completed = true
            item.dirty = true
            step.result, step.ended_at, step.job = result, ended_at, nil
            item.result, item.job, item.active = result, nil, nil
            local success = result.code == 0 and result.signal == 0
            step.status = item.stop_requested and "stopped" or (success and "succeeded" or "failed")
            callback(state.on_step_exit, item, step, result, state)
            render_output(state, item)
            if item.stop_requested or state.cancelled then
                complete_item(state, item, "stopped", "Remaining commands were not started")
            elseif not success then
                complete_item(state, item, "failed", "Command " .. item.index .. " failed; later commands were not started")
            elseif item.index == #item.steps then
                complete_item(state, item, "succeeded")
            else
                -- Yield between commands so cancellation can prevent the next launch.
                vim.schedule(function() start_step(state, item) end)
            end
        end)
    end)
    if ok then
        step.job, item.job = job, job
    else
        step.completed, step.status, step.ended_at = true, "failed", vim.uv.hrtime()
        step.reason = "Could not start: " .. tostring(job)
        item.result = nil
        callback(state.on_step_exit, item, step, nil, state)
        complete_item(state, item, "failed", step.reason)
    end
end

pump = function(state)
    if state.cancelled or state.finished or state.pumping then return end
    state.pumping, state.launching = true, true
    local n = counts(state).running
    for _, item in ipairs(state.items) do
        if n >= state.concurrency then break end
        if item.status == "ready" then
            start_step(state, item)
            if item.status == "running" then n = n + 1 end
        end
    end
    state.pumping, state.launching = false, false
    finish(state)
end

function M.stop(state, dir)
    state = state or M.latest()
    if not state or not state.running then return end
    local target = dir and directory(dir)
    if not target then state.cancelled, state.phase = true, "stopping" end
    for _, item in ipairs(state.items) do
        if (item.status == "ready" or item.status == "running") and (not target or item.dir == target) then
            item.stop_requested = true
            remaining(item, "stopped", "Not started after stop request")
            if item.job then
                local ok, err = pcall(item.job.kill, item.job, 2)
                if not ok then notify("Could not interrupt: " .. tostring(err), vim.log.levels.WARN) end
            elseif not item.active then
                complete_item(state, item, "stopped", "Not started after stop request")
            end
        end
    end
    render_summary(state)
    finish(state)
end

function M.active(predicate)
    local result = {}
    for _, state in ipairs(runs) do
        if state.running then
            for _, item in ipairs(state.items) do
                if item.status == "running" or item.status == "ready" then
                    local entry = { state = state, item = item, step = item.active or item.steps[math.max(1, item.index)] }
                    if not predicate or predicate(entry) then result[#result + 1] = entry end
                end
            end
        end
    end
    return result
end

function M.select_stop(predicate, label)
    label = label or "Batch"
    local entries = M.active(predicate)
    local function interrupt(entry)
        local current = entry.item.active or entry.item.steps[math.max(1, entry.item.index)]
        if (entry.item.status == "running" or entry.item.status == "ready") and current == entry.step then M.stop(entry.state, entry.item.dir) end
    end
    if #entries == 0 then return vim.notify(label .. ": no running jobs", vim.log.levels.INFO) end
    if #entries == 1 then return interrupt(entries[1]) end
    local choices = { { all = true } }
    vim.list_extend(choices, entries)
    vim.ui.select(choices, {
        prompt = label .. ": interrupt which job?",
        format_item = function(entry)
            if entry.all then return "All matching jobs (" .. #entries .. ")" end
            return string.format("#%d %s | %s | %s", entry.state.id, entry.state.title,
                one_line(entry.item.dir), entry.step.command.text)
        end,
    }, function(choice)
        if not choice then return end
        if choice.all then
            for _, entry in ipairs(entries) do interrupt(entry) end
        else
            interrupt(choice)
        end
    end)
end

local function array(value, name)
    assert(type(value) == "table" and vim.islist(value), name .. " must be an array")
end

local function specification(spec)
    if type(spec) == "string" then
        local name = spec
        assert(configured[name], "Unknown batch: " .. name)
        spec = vim.deepcopy(configured[name])
        spec.name, spec.summary_only = name, true
    end
    assert(type(spec) == "table", "Batch specification must be a table")
    assert(spec.commands == nil or (spec.exe == nil and spec.args == nil), "Use commands OR exe/args, not both")
    local input = spec.commands or { { exe = spec.exe, args = spec.args } }
    array(input, "commands")
    assert(#input > 0, "commands must contain at least one command")
    local commands = {}
    for _, command in ipairs(input) do
        assert(type(command) == "table", "Each command must contain exe and optional args")
        assert(type(command.exe) == "string" and command.exe ~= "" and not command.exe:find("%z"), "exe must be a nonempty string")
        local args = command.args or {}
        array(args, "args")
        local argv = { expand(command.exe) }
        for _, arg in ipairs(args) do
            assert(type(arg) == "string" and not arg:find("%z"), "args must contain strings without NUL bytes")
            argv[#argv + 1] = arg
        end
        commands[#commands + 1] = { exe = argv[1], argv = argv, text = command_string(argv) }
    end
    if spec.dirs ~= nil then array(spec.dirs, "dirs") end
    for _, dir in ipairs(spec.dirs or {}) do
        assert(type(dir) == "string" and dir ~= "" and not dir:find("%z"), "dirs must contain nonempty paths")
    end
    for _, key in ipairs({ "on_step_exit", "on_job_exit", "on_complete", "on_open" }) do
        assert(spec[key] == nil or type(spec[key]) == "function", key .. " must be a function")
    end
    for _, field in ipairs({ "concurrency", "max_output_bytes" }) do
        assert(spec[field] == nil or (type(spec[field]) == "number" and spec[field] >= 1 and spec[field] % 1 == 0), field .. " must be a positive integer")
    end
    return spec, commands
end

local function prepare(spec, preview)
    local commands
    spec, commands = specification(spec)
    serial = serial + 1
    local state = {
        id = serial,
        name = spec.name,
        title = one_line(spec.name or spec.title or commands[1].exe),
        cwd = directory(vim.fn.getcwd()),
        commands = commands,
        owner = spec.owner,
        concurrency = spec.concurrency or options.concurrency,
        max_output_bytes = spec.max_output_bytes or options.max_output_bytes,
        log_dir = spec.log_dir and directory(spec.log_dir) or options.log_dir,
        phase = preview and "preview" or "running",
        running = not preview,
        finished = preview,
        hidden = spec.show == false,
        summary_only = spec.summary_only == true,
        items = {},
        rows = {},
        on_step_exit = spec.on_step_exit,
        on_job_exit = spec.on_job_exit,
        on_complete = spec.on_complete,
        on_open = spec.on_open,
    }
    local seen = {}
    -- Omitted dirs runs in cwd. An explicit empty list runs nowhere.
    for _, dir in ipairs(spec.dirs or { state.cwd }) do
        dir = directory(dir)
        if not seen[dir] then
            seen[dir] = true
            local item = { id = #state.items + 1, dir = dir, status = "ready", index = 0, steps = {}, stdout = {}, stderr = {} }
            for _, command in ipairs(commands) do
                local selected = command
                if spec.workspace and (command.exe == "zig" or command.exe == "zls") then
                    local ws = require("workspace").for_root(vim.fs.root(dir, { "build.zig", "build.zig.zon", ".git" }) or dir)
                    selected = vim.deepcopy(command)
                    selected.exe = command.exe == "zig" and ws.zig_exe or ws.zls_exe
                    selected.argv[1] = selected.exe
                    selected.text = command_string(selected.argv)
                end
                item.steps[#item.steps + 1] = { command = selected, status = "pending", stdout = {}, stderr = {} }
            end
            local stat = vim.uv.fs_stat(dir)
            if not stat or stat.type ~= "directory" then
                item.status, item.reason, item.done = "skipped", "Directory is unavailable", true
                remaining(item, "skipped", item.reason)
            end
            state.items[#state.items + 1] = item
        end
    end
    table.sort(state.items, function(a, b)
        if (a.status == "skipped") ~= (b.status == "skipped") then return b.status == "skipped" end
        return a.id < b.id
    end)
    runs[#runs + 1] = state
    prune_history()
    return state
end

local function start(state, preview)
    local win = vim.api.nvim_get_current_win()
    if preview then
        if not state.hidden then M.open_summary(state) end
    else
        pump(state)
        if not state.finished then
            state.timer = vim.fn.timer_start(200, function()
                for _, item in ipairs(state.items) do render_output(state, item) end
                -- Only the small visible summary updates elapsed time, not the complete logs.
                if visible(state.buf) then render_summary(state) end
            end, { ["repeat"] = -1 })
        end
        if not state.hidden then M.open(state) end
    end
    if vim.api.nvim_win_is_valid(win) then vim.api.nvim_set_current_win(win) end
    return state
end

function M.preview(spec)
    return start(prepare(spec, true), true)
end

function M.run(spec)
    return start(prepare(spec, false), false)
end

local function names(lead)
    local result = {}
    for name in pairs(configured) do
        if name:sub(1, #(lead or "")) == (lead or "") then result[#result + 1] = name end
    end
    table.sort(result)
    return result
end

local function catalog()
    if not reusable(catalog_buf) then catalog_buf = scratch("batch://configured") end
    local lines = { "Batch: configured commands", "cwd: " .. one_line(directory(vim.fn.getcwd())),
        ":Batch <name> previews. :Batch! <name> executes.", "" }
    for _, name in ipairs(names()) do
        local spec, commands = specification(name)
        lines[#lines + 1] = name .. ":"
        for i, command in ipairs(commands) do lines[#lines + 1] = "    cmd" .. i .. ": " .. command.text end
        lines[#lines + 1] = "    dirs:"
        for _, dir in ipairs(spec.dirs or { vim.fn.getcwd() }) do lines[#lines + 1] = "        " .. one_line(directory(dir)) end
        if spec.dirs and #spec.dirs == 0 then lines[#lines + 1] = "        (none)" end
        lines[#lines + 1] = ""
    end
    if #names() == 0 then lines[#lines + 1] = "No named batches configured." end
    put_lines(catalog_buf, lines)
    show(catalog_buf)
end

function M.setup(opts)
    opts = opts or {}
    for _, key in ipairs({ "concurrency", "max_output_bytes", "max_history" }) do
        if opts[key] ~= nil then
            assert(type(opts[key]) == "number" and opts[key] >= 1 and opts[key] % 1 == 0, key .. " must be a positive integer")
            options[key] = opts[key]
        end
    end
    options.log_dir = opts.log_dir and directory(opts.log_dir) or nil
    local group = vim.api.nvim_create_augroup("1337.batch", { clear = true })
    vim.api.nvim_create_autocmd("BufEnter", { group = group, callback = function(e)
        local context = contexts[e.buf]
        if context and context.item then render_output(context.state, context.item, true) end
    end })
    vim.api.nvim_create_autocmd("VimLeavePre", { group = group, callback = function()
        for _, state in ipairs(runs) do
            state.cancelled = true
            if state.timer then vim.fn.timer_stop(state.timer); state.timer = nil end
            for _, item in ipairs(state.items) do
                if item.job then pcall(item.job.kill, item.job, 15) end
                for _, fd in pairs(item.log_fds or {}) do pcall(vim.uv.fs_close, fd) end
                item.log_fds = nil
            end
        end
    end })
    local definitions = opts.batches or {}
    assert(type(definitions) == "table", "batches must be a table of named specifications")
    for name, spec in pairs(definitions) do
        assert(type(spec) == "table", "Each named batch must be a specification table")
        assert(type(name) == "string" and name:match("^[%w_.-]+$"), "Batch names must use letters, digits, _, ., or -")
        specification(spec)
    end
    configured = vim.deepcopy(definitions)
    vim.api.nvim_create_user_command("Batch", function(command)
        local ok, err = pcall(function()
            if command.args == "" then
                assert(not command.bang, "Use :Batch! <name> to execute a specific batch")
                catalog()
            elseif command.bang then
                M.run(command.args)
            else
                M.preview(command.args)
            end
        end)
        if not ok then notify(tostring(err), vim.log.levels.ERROR) end
    end, { nargs = "?", bang = true, complete = names, desc = "List or preview named batches; add ! to execute" })
    vim.api.nvim_create_user_command("BatchOutput", function(command)
        local name = command.args
        local state = M.latest(name ~= "" and function(run) return run.name == name end or nil)
        if not state then return notify("No matching batch output yet") end
        M.open(state)
    end, { nargs = "?", complete = names, desc = "Show the latest output, optionally for a named batch" })
    vim.api.nvim_create_user_command("BatchStop", function() M.select_stop() end, {
        desc = "Interrupt one running directory sequence, or choose all",
    })
end

return M
