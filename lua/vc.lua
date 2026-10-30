local M = {}

local git_buffers = {}

local function git_update(buf)
    if not vim.api.nvim_buf_is_loaded(buf) then return end

    local state = git_buffers[buf]
    if not state then return end

    local added, changed, removed = 0, 0, 0
    local hunks = {}

    if state.base and not state.base:find("\0", 1, true) then
        local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
        local text = table.concat(lines, "\n")

        if vim.bo[buf].endofline then text = text .. "\n" end

        hunks = vim.text.diff(state.base, text, { result_type = "indices" })

        for _, hunk in ipairs(hunks) do
            local old_count, new_count = hunk[2], hunk[4]
            local both = math.min(old_count, new_count)

            added = added + new_count - both
            changed = changed + both
            removed = removed + old_count - both
        end
    end

    state.status = {
        head = state.branch,
        added = added,
        changed = changed,
        removed = removed,
        hunks = hunks,
    }

    vim.b[buf].git_status_dict = state.branch and state.status or nil

    vim.api.nvim_exec_autocmds("User", {
        pattern = "1337VCUpdated",
        data = { buf = buf },
    })
end

local function git_refresh(buf)
    if not vim.api.nvim_buf_is_valid(buf) or vim.bo[buf].buftype ~= "" then return end
    if vim.fn.executable("git") ~= 1 then return end

    local path = vim.api.nvim_buf_get_name(buf)
    if path == "" then return end

    local state = git_buffers[buf] or {}
    git_buffers[buf] = state

    state.version = (state.version or 0) + 1
    local version = state.version
    local dir = vim.fs.dirname(path)

    local function receive(field, transform)
        return function(result)
            vim.schedule(function()
                if not vim.api.nvim_buf_is_valid(buf) or git_buffers[buf] ~= state
                    or state.version ~= version or vim.api.nvim_buf_get_name(buf) ~= path then
                    return
                end

                state[field] = transform(result)
                git_update(buf)
            end)
        end
    end

    vim.system({ "git", "-C", dir, "show", ":./" .. vim.fs.basename(path) }, { text = true },
        receive("base", function(result)
            return result.code == 0 and result.stdout or nil
        end))

    vim.system({ "git", "-C", dir, "rev-parse", "--abbrev-ref", "HEAD" }, { text = true },
        receive("branch", function(result)
            return result.code == 0 and (result.stdout or ""):match("[^\r\n]+") or nil
        end))
end

local function git_schedule(buf)
    local state = git_buffers[buf]
    if not state then return end

    state.update = (state.update or 0) + 1
    local update = state.update

    vim.defer_fn(function()
        if git_buffers[buf] == state and state.update == update then
            git_update(buf)
        end
    end, 200)
end

function M.get(buf)
    buf = (buf == nil or buf == 0) and vim.api.nvim_get_current_buf() or buf

    local state = git_buffers[buf]
    return state and state.status or nil
end

function M.setup()
    local group = vim.api.nvim_create_augroup("1337.vc", { clear = true })

    vim.api.nvim_create_autocmd({ "BufEnter", "BufReadPost", "BufWritePost", "FocusGained" }, {
        group = group,
        callback = function(args)
            git_refresh(args.buf)
        end,
    })

    vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
        group = group,
        callback = function(args)
            git_schedule(args.buf)
        end,
    })

    vim.api.nvim_create_autocmd("BufWipeout", {
        group = group,
        callback = function(args)
            git_buffers[args.buf] = nil
        end,
    })

    vim.schedule(function()
        git_refresh(vim.api.nvim_get_current_buf())
    end)
end

return M
