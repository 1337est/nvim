local M = {}
local integration, current
local defaults = { ".git", ".zig-cache", "zig-cache", "zig-out", "zig-pkg", "node_modules" }

local function notify(message, level)
    vim.notify("ZigBatch: " .. message, level or vim.log.levels.INFO)
end

local function config_path()
    return vim.fn.stdpath("config") .. "/lua/zig_tasks.lua"
end

local function expand(path)
    return path:sub(1, 2) == "~/" and (vim.env.HOME .. path:sub(2)) or path
end

local function stamp(path)
    local stat = vim.uv.fs_stat(path)
    if not stat or stat.type ~= "file" then return nil end
    return table.concat({ stat.size, stat.mtime.sec, stat.mtime.nsec }, ":")
end

local function counts(state)
    local result = { ready = 0, skipped = 0, running = 0, succeeded = 0, failed = 0, stopped = 0 }
    for _, project in ipairs(state.projects) do
        result[project.status] = result[project.status] + 1
    end
    return result
end

local function render(state)
    if not state.buf or not vim.api.nvim_buf_is_loaded(state.buf) then return end
    local n = counts(state)
    local lines = {
        "ZigBatch: " .. state.name .. " [" .. state.phase .. "]",
        "cmd: " .. table.concat(vim.tbl_map(vim.fn.shellescape, state.argv), " "),
        string.format("%d ready; %d running; %d succeeded; %d failed; %d skipped; %d stopped",
            n.ready, n.running, n.succeeded, n.failed, n.skipped, n.stopped),
        "Enter on a started project opens its Zig output. :ZigBatchStop stops the queue.",
        "",
    }
    state.rows = {}
    for _, note in ipairs(state.notes) do
        vim.list_extend(lines, vim.split(note, "\n", { plain = true }))
    end
    if #state.notes > 0 then lines[#lines + 1] = "" end
    for _, project in ipairs(state.projects) do
        lines[#lines + 1] = "[" .. project.status .. "] " .. project.cwd:gsub("\n", "\\n")
        state.rows[#lines] = project
        if project.reason then
            for _, line in ipairs(vim.split(project.reason, "\n", { plain = true, trimempty = true })) do
                lines[#lines + 1] = "    " .. line
                state.rows[#lines] = project
            end
        end
    end
    vim.bo[state.buf].modifiable = true
    vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
    vim.bo[state.buf].modifiable = false
    vim.bo[state.buf].modified = false
end

local function show(state)
    if not state then return notify("No batch output yet") end
    if not state.buf or not vim.api.nvim_buf_is_loaded(state.buf) then
        state.buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_name(state.buf, "zigbatch://output/" .. state.buf)
        vim.bo[state.buf].bufhidden = "hide"
        vim.bo[state.buf].filetype = "zigoutput"
        vim.keymap.set("n", "<CR>", function()
            local project = state.rows[vim.api.nvim_win_get_cursor(0)[1]]
            if project and project.started then
                integration.output(project.cwd)
            elseif project then
                notify("This project has no output from this batch")
            end
        end, { buffer = state.buf, silent = true, desc = "Open this project's Zig output" })
        render(state)
    end
    local win = vim.fn.bufwinid(state.buf)
    if win ~= -1 then
        vim.api.nvim_set_current_win(win)
    else
        vim.cmd("botright 12split")
        vim.api.nvim_win_set_buf(0, state.buf)
    end
end

local function finish(state, phase)
    if state.finished then return end
    state.finished, state.running = true, false
    state.phase = phase or (state.cancelled and "stopped" or "complete")
    if state.cancelled then
        for _, project in ipairs(state.projects) do
            if project.status == "ready" then
                project.status, project.reason = "stopped", "Not started after :ZigBatchStop"
            end
        end
    end
    render(state)
    local n = counts(state)
    if state.execute and state.phase ~= "failed" then
        vim.fn.setqflist({}, " ", {
            nr = "$", title = "ZigBatch " .. state.name .. " [" .. state.phase .. "]", items = state.items,
        })
        state.qfid = vim.fn.getqflist({ id = 0 }).id
    end
    if state.phase == "preview" then
        notify(n.ready .. " project(s) ready. Run :ZigBatch! " .. state.name .. " to execute")
    else
        notify(string.format("%s: %d succeeded, %d failed, %d skipped, %d stopped",
                state.phase, n.succeeded, n.failed, n.skipped, n.stopped),
            (n.failed > 0 or state.phase == "failed") and vim.log.levels.WARN or vim.log.levels.INFO)
    end
end

local function manifest_buffers(manifest)
    local result = {}
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_loaded(buf) then
            local name = vim.api.nvim_buf_get_name(buf)
            if name ~= "" and (vim.uv.fs_realpath(name) or name) == manifest then
                result[#result + 1] = buf
            end
        end
    end
    return result
end

local function fallback(state, project, message)
    state.items[#state.items + 1] = {
        filename = project.manifest, lnum = 1, col = 1, type = "E", text = message,
    }
end

local function run_next(state)
    if state.cancelled then return finish(state) end
    local project
    while state.index < #state.projects do
        state.index = state.index + 1
        if state.projects[state.index].status == "ready" then
            project = state.projects[state.index]
            break
        end
    end
    if not project then return finish(state) end

    local reason
    for _, buf in ipairs(manifest_buffers(project.manifest)) do
        if vim.bo[buf].modified then reason = "Manifest has unsaved edits in Neovim" end
    end
    if integration.busy(project.cwd) then reason = "Another Zig command is running in this project" end
    if state.fetch and stamp(project.manifest) ~= state.stamps[project.manifest] then
        reason = "Manifest changed since discovery; run the task again"
    end
    local build = vim.uv.fs_stat(project.cwd .. "/build.zig")
    if not build or build.type ~= "file" then reason = "No adjacent build.zig" end
    if reason then
        project.status, project.reason = "skipped", reason
        render(state)
        return vim.schedule(function() run_next(state) end)
    end

    project.status, state.active_project = "running", project
    render(state)
    local ok, job, err = pcall(integration.run, state.argv, project.cwd, {
        show = false,
        notify = false,
        on_exit = function(result, items)
            state.job, state.active_project = nil, nil
            project.started = true
            local success = result.code == 0 and result.signal == 0
            project.status = success and "succeeded" or (state.cancelled and "stopped" or "failed")
            project.reason = string.format("exit %d, signal %d", result.code, result.signal)
            vim.list_extend(state.items, items or {})
            if not success and not state.cancelled and #(items or {}) == 0 then
                fallback(state, project, "zig " .. table.concat(state.task.argv, " ") .. ": " .. project.reason)
            end
            if state.fetch then
                for _, buf in ipairs(manifest_buffers(project.manifest)) do
                    if not vim.bo[buf].modified then vim.cmd("silent! checktime " .. buf) end
                end
            end
            render(state)
            vim.schedule(function() run_next(state) end)
        end,
    })
    if ok and job then
        project.started = true
        if state.active_project == project then state.job = job end
    else
        state.active_project = nil
        project.status, project.reason = "failed", "Could not start: " .. tostring(ok and err or job)
        fallback(state, project, project.reason)
        render(state)
        vim.schedule(function() run_next(state) end)
    end
end

local function collect_results(state, decoded)
    for _, value in ipairs(decoded.projects) do
        local project = { manifest = value.manifest, cwd = vim.fs.dirname(value.manifest), status = "ready" }
        local dep = state.task.dependency and (value.dependencies or {})[state.task.dependency]
        local build = vim.uv.fs_stat(project.cwd .. "/build.zig")
        if not build or build.type ~= "file" then
            project.reason = "No adjacent build.zig; this is not an eligible project root"
        elseif state.task.dependency and not dep then
            project.reason = "No direct dependency named " .. state.task.dependency
        elseif state.fetch and dep.path ~= nil then
            project.reason = "Local .path dependency; no fetch is needed"
        elseif state.fetch and (type(dep.url) ~= "string" or type(dep.hash) ~= "string") then
            project.reason = "Dependency has no URL and hash pair"
        end
        if project.reason then project.status = "skipped" end
        state.projects[#state.projects + 1] = project
    end
    for _, value in ipairs(decoded.errors) do
        state.projects[#state.projects + 1] = {
            manifest = value.manifest,
            cwd = vim.fs.dirname(value.manifest),
            status = "skipped",
            reason = "Cannot parse manifest: " .. value.error,
        }
    end
    table.sort(state.projects, function(a, b) return a.manifest < b.manifest end)
    if state.execute then
        state.phase, state.index = "running", 0
        render(state)
        run_next(state)
    else
        finish(state, "preview")
    end
end

local function parse_manifests(state)
    if state.cancelled then return finish(state) end
    if #state.manifests == 0 then
        state.notes[#state.notes + 1] = "No build.zig.zon files found."
        return finish(state, state.execute and "complete" or "preview")
    end
    table.sort(state.manifests)
    state.phase = "parsing " .. #state.manifests .. " manifest(s)"
    render(state)
    local argv = {
        expand(state.config.zig or "zig"), "run",
        vim.fn.stdpath("config") .. "/assets/zig_manifest_index.zig",
        "--cache-dir", vim.fn.stdpath("cache") .. "/zig-batch", "--",
    }
    local ok, job = pcall(vim.system, argv, {
        stdin = vim.json.encode(state.manifests), text = true,
    }, function(result)
        vim.schedule(function()
            state.scan_job = nil
            if state.cancelled then return finish(state) end
            local decoded_ok, decoded = pcall(vim.json.decode, result.stdout or "")
            if result.code ~= 0 or not decoded_ok or type(decoded) ~= "table"
                or type(decoded.projects) ~= "table" or type(decoded.errors) ~= "table" then
                local stderr = result.stderr or ""
                state.notes[#state.notes + 1] = "Manifest helper failed: "
                    .. (stderr ~= "" and stderr or tostring(decoded))
                return finish(state, "failed")
            end
            collect_results(state, decoded)
        end)
    end)
    if ok then
        state.scan_job = job
    else
        state.notes[#state.notes + 1] = "Could not start manifest helper: " .. tostring(job)
        finish(state, "failed")
    end
end

local function discover(state)
    if state.cancelled then return finish(state) end
    for _ = 1, 64 do
        local dir = table.remove(state.dirs)
        if not dir then return parse_manifests(state) end
        if not state.visited[dir] then
            state.visited[dir] = true
            local request, err = vim.uv.fs_scandir(dir)
            if not request then
                state.notes[#state.notes + 1] = "Cannot read " .. dir .. ": " .. tostring(err)
            else
                while true do
                    local name, kind = vim.uv.fs_scandir_next(request)
                    if not name then break end
                    local path = dir .. (dir:sub(-1) == "/" and "" or "/") .. name
                    if not kind then
                        local stat = vim.uv.fs_lstat(path)
                        kind = stat and stat.type
                    end
                    if kind == "directory" and not state.excluded[name] then
                        state.dirs[#state.dirs + 1] = path
                    elseif kind == "file" and name == "build.zig.zon" then
                        state.manifests[#state.manifests + 1] = path
                        state.stamps[path] = stamp(path)
                    end
                end
            end
        end
    end
    vim.schedule(function() discover(state) end)
end

local function load_task(name)
    local config = dofile(config_path())
    assert(type(config) == "table" and type(config.tasks) == "table", "zig_tasks.lua must return a task configuration")
    assert(type(config.roots) == "table" and #config.roots > 0, "Configure at least one search root")
    assert(config.exclude == nil or type(config.exclude) == "table", "exclude must be a list of directory names")
    for _, name in ipairs(config.exclude or {}) do
        assert(type(name) == "string", "Every exclude entry must be a directory name")
    end
    assert(config.zig == nil or (type(config.zig) == "string" and config.zig ~= ""), "zig must be an executable name or path")
    local task = config.tasks[name]
    assert(type(task) == "table", "Unknown task: " .. name)
    assert(type(task.argv) == "table" and #task.argv > 0, "Task argv must contain Zig arguments")
    for _, arg in ipairs(task.argv) do assert(type(arg) == "string" and arg ~= "", "Every argv entry must be a nonempty string") end
    assert(task.zig == nil or (type(task.zig) == "string" and task.zig ~= ""), "Task zig must be an executable name or path")
    assert(task.dependency == nil or (type(task.dependency) == "string" and task.dependency ~= ""), "dependency must be an existing manifest key")
    if task.argv[1] == "fetch" then
        assert(task.dependency, "Fetch tasks require a dependency selector")
        local saves, url = 0, false
        for _, arg in ipairs(task.argv) do
            if arg:match("^%-%-save") then
                assert(arg == "--save=" .. task.dependency or arg == "--save-exact=" .. task.dependency,
                    "Fetch must save under the selected dependency name")
                saves = saves + 1
            end
            if arg:match("^%a[%w+.-]*://") then url = true end
        end
        assert(saves == 1 and url, "Fetch tasks require one named --save flag and an explicit package URL")
    end
    for _, root in ipairs(config.roots) do assert(type(root) == "string" and root ~= "", "Search roots must be nonempty paths") end
    return config, task
end

function M.setup(options)
    integration = options
    vim.api.nvim_create_user_command("ZigBatch", function(command)
        if current and current.running then return notify("A batch is active; use :ZigBatchStop", vim.log.levels.WARN) end
        local ok, config, task = pcall(load_task, command.args)
        if not ok then return notify(tostring(config), vim.log.levels.ERROR) end
        local state = {
            name = command.args,
            config = config,
            task = task,
            execute = command.bang,
            fetch = task.argv[1] == "fetch",
            phase = "discovering",
            running = true,
            projects = {},
            notes = {},
            items = {},
            manifests = {},
            stamps = {},
            dirs = {},
            visited = {},
            excluded = {},
            argv = { expand(task.zig or config.zig or "zig") },
        }
        for _, arg in ipairs(task.argv) do state.argv[#state.argv + 1] = expand(arg) end
        for _, name in ipairs(defaults) do state.excluded[name] = true end
        for _, name in ipairs(config.exclude or {}) do state.excluded[name] = true end
        for _, root in ipairs(config.roots) do
            local path = vim.uv.fs_realpath(vim.fn.expand(root))
            local stat = path and vim.uv.fs_stat(path)
            if stat and stat.type == "directory" then
                state.dirs[#state.dirs + 1] = path
            else
                state.notes[#state.notes + 1] = "Search root is unavailable: " .. root
            end
        end
        current = state
        local win = vim.api.nvim_get_current_win()
        show(state)
        vim.api.nvim_set_current_win(win)
        vim.schedule(function() discover(state) end)
    end, {
        nargs = 1,
        bang = true,
        desc = "Preview a configured batch; add ! to execute",
        complete = function(lead)
            local ok, config = pcall(dofile, config_path())
            local names = {}
            if ok and type(config) == "table" and type(config.tasks) == "table" then
                for name in pairs(config.tasks) do
                    if type(name) == "string" and name:sub(1, #lead) == lead then names[#names + 1] = name end
                end
            end
            table.sort(names)
            return names
        end,
    })
    vim.api.nvim_create_user_command("ZigBatchOutput", function()
        show(current)
        if current and current.qfid then
            local qf = vim.fn.getqflist({ id = current.qfid, nr = 0 })
            if qf.id == current.qfid and qf.nr > 0 then vim.cmd(("silent %dchistory"):format(qf.nr)) end
        end
    end, { desc = "Show batch plan, results, and aggregate quickfix" })
    vim.api.nvim_create_user_command("ZigBatchStop", function()
        if not current or not current.running then return notify("No batch is running") end
        current.cancelled = true
        current.phase = "stopping"
        render(current)
        local job = current.job or current.scan_job
        if job then
            -- The process may have exited while its completion callback is queued.
            pcall(job.kill, job, 2)
        else
            finish(current)
        end
    end, { desc = "Interrupt the batch and stop its remaining jobs" })
end

return M
