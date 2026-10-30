-- Shared project context. No project-local Lua is evaluated and no tool is built here.
local M = {}
local opts, records, buffers, overrides = {}, {}, {}, {}
local initialized = false
local function absolute(path)
    if path:sub(1, 2) == "~/" then path = (vim.env.HOME or vim.fn.expand("~")) .. path:sub(2) end
    path = vim.fs.normalize(vim.fn.fnamemodify(path, ":p")):gsub("/+$", "")
    if path == "" then path = "/" end
    return vim.uv.fs_realpath(path) or path
end
local function inside(path, root)
    return path == root or root == "/" or path:sub(1, #root + 1) == root .. "/"
end
local function executable(value)
    if value:sub(1, 2) == "~/" then value = (vim.env.HOME or vim.fn.expand("~")) .. value:sub(2) end
    local path = vim.fn.exepath(value)
    return path ~= "" and absolute(path) or value
end
local function event(record, old)
    vim.api.nvim_exec_autocmds("User", {
        pattern = "1337WorkspaceChanged", modeline = false,
        data = { root = record.root, key = record.key, generation = record.generation, old = old },
    })
end
local function validate(values)
    for _, field in ipairs({ "zig_exe", "zls_exe" }) do
        assert(values[field] == nil or (type(values[field]) == "string" and values[field] ~= "" and not values[field]:find("%z")), field .. " must be a nonempty string")
    end
    if values.build_options then
        assert(vim.islist(values.build_options), "build_options must be an array")
        for _, value in ipairs(values.build_options) do
            assert(type(value) == "string" and value ~= "" and value:sub(1, 1) ~= "-" and not value:find("%z"), "build_options must omit the -D prefix")
        end
    end
    assert(values.trusted == nil or type(values.trusted) == "boolean", "trusted must be boolean")
end
local function construct(root, generation)
    local values = vim.deepcopy(opts.defaults or {})
    local best
    for path, profile in pairs(opts.projects or {}) do
        if inside(root, path) and (not best or #path > #best) then best = path; values = vim.tbl_deep_extend("force", vim.deepcopy(opts.defaults or {}), profile) end
    end
    if overrides[root] then values = vim.tbl_deep_extend("force", values, overrides[root]) end
    -- Arrays are replacements, not recursive table merges.
    if overrides[root] and overrides[root].build_options then values.build_options = vim.deepcopy(overrides[root].build_options)
    elseif best and opts.projects[best].build_options then values.build_options = vim.deepcopy(opts.projects[best].build_options) end
    validate(values)
    local trusted = values.trusted == true
    if values.trusted == nil then
        for _, parent in ipairs(opts.trusted_roots or {}) do if inside(root, parent) then trusted = true; break end end
    end
    local record = {
        root = root, zig_exe = executable(values.zig_exe or "zig"), zls_exe = executable(values.zls_exe or "zls"),
        build_options = vim.deepcopy(values.build_options or {}), trusted = trusted, generation = generation or 1,
    }
    -- Fixed-order serialization: contexts differing in options/toolchains cannot share a daemon.
    record.key = vim.json.encode({ root, record.zig_exe, record.zls_exe, record.build_options, trusted, record.generation })
    return record
end
function M.for_root(root)
    root = absolute(root)
    if not records[root] then records[root] = construct(root) end
    return records[root]
end
function M.root(buf)
    if buf == nil or buf == 0 then buf = vim.api.nvim_get_current_buf() end
    local name = vim.api.nvim_buf_get_name(buf)
    local root = vim.fs.root(buf, opts.root_markers or { "build.zig", "build.zig.zon", ".git" })
    return absolute(root or (name ~= "" and vim.fs.dirname(name)) or vim.fn.getcwd())
end
function M.get(buf)
    if buf == nil or buf == 0 then buf = vim.api.nvim_get_current_buf() end
    local root = buffers[buf]
    if not root then root = M.root(buf); buffers[buf] = root end
    return M.for_root(root)
end
-- Rendering calls only peek: no filesystem walks or subprocesses on the statusline.
function M.peek(buf)
    if buf == nil or buf == 0 then buf = vim.api.nvim_get_current_buf() end
    return buffers[buf] and records[buffers[buf]] or nil
end
function M.set(root, patch)
    root = absolute(root)
    validate(patch)
    local old = M.for_root(root)
    overrides[root] = vim.tbl_deep_extend("force", overrides[root] or {}, patch)
    if patch.build_options then overrides[root].build_options = vim.deepcopy(patch.build_options) end
    records[root] = construct(root, old.generation + 1)
    event(records[root], { key = old.key, zig_exe = old.zig_exe, zls_exe = old.zls_exe, trusted = old.trusted })
    return records[root]
end
function M.refresh(root)
    root = absolute(root or M.get().root)
    local old = M.for_root(root)
    records[root] = construct(root, old.generation + 1)
    event(records[root], { key = old.key, zig_exe = old.zig_exe, zls_exe = old.zls_exe, trusted = old.trusted })
    return records[root]
end
function M.setup(config)
    opts = config or {}
    validate(opts.defaults or {})
    local projects = {}
    for root, values in pairs(opts.projects or {}) do validate(values); projects[absolute(root)] = values end
    opts.projects = projects
    for i, root in ipairs(opts.trusted_roots or {}) do opts.trusted_roots[i] = absolute(root) end
    records, buffers = {}, {}
    local group = vim.api.nvim_create_augroup("1337.workspace", { clear = true })
    vim.api.nvim_create_autocmd({ "BufReadPost", "BufNewFile", "BufFilePost", "DirChanged" }, {
        group = group, callback = function(e)
            if e.event == "DirChanged" then buffers = {}; return end
            buffers[e.buf] = nil
            if vim.bo[e.buf].buftype == "" then M.get(e.buf) end
        end,
    })
    vim.api.nvim_create_autocmd("BufWipeout", { group = group, callback = function(e) buffers[e.buf] = nil end })
    vim.api.nvim_create_user_command("ZweWorkspace", function()
        local r = M.get(); vim.notify(vim.inspect(r), vim.log.levels.INFO, { title = "ZWE workspace" })
    end, { desc = "Show shared workspace context" })
    vim.api.nvim_create_user_command("ZweToolchain", function(c)
        assert(#c.fargs <= 2, "Usage: ZweToolchain ZIG [ZLS]")
        local zig = executable(c.fargs[1])
        local zls = c.fargs[2] and executable(c.fargs[2]) or M.get().zls_exe
        if vim.fn.executable(zig) ~= 1 or vim.fn.executable(zls) ~= 1 then error("Zig and ZLS must be executable") end
        M.set(M.get().root, { zig_exe = zig, zls_exe = zls })
    end, { nargs = "+", complete = "file", desc = "Select workspace Zig [ZLS]; restart matching services" })
    vim.api.nvim_create_user_command("ZweBuildOptions", function(c)
        M.set(M.get().root, { build_options = c.fargs })
    end, { nargs = "*", desc = "Replace workspace build options; omit -D; no args clears them" })
    vim.api.nvim_create_user_command("ZweTrust", function(c)
        M.set(M.get().root, { trusted = not c.bang })
        vim.notify(c.bang and "ZWE build configuration disabled for this workspace." or "ZWE may now execute this workspace's build.zig configuration.")
    end, { bang = true, desc = "Trust workspace build.zig; ! revokes trust (session only)" })
    vim.api.nvim_create_user_command("ZweWorkspaceRefresh", function() M.refresh() end, {
        desc = "Re-resolve tool paths and restart workspace services",
    })
    initialized = true
    return M
end
function M.initialized() return initialized end
return M
