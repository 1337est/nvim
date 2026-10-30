local M = {}

-- mode to map commands, requires custom zig parser
-- TODO: Update helpful_message to suggest to use the :Zig plugin

local zig_index_parser_file, runtime_doc_index_file, zig_parser_output_file, helpful_message
local cache = { stamp = nil, modes = {} }
local function stamp()
    local s = vim.uv.fs_stat(zig_parser_output_file)
    if not s then return "missing:" .. zig_parser_output_file end
    return table.concat({ zig_parser_output_file, runtime_doc_index_file, s.size, s.mtime.sec, s.mtime.nsec or 0 }, ":")
end

local function show_mappings(requested_mode)
    local mode = require("utils").mode_info(requested_mode).map
    local mappings = {}
    local priorities = {}

    local current = stamp()
    if cache.stamp ~= current then cache = { stamp = current, modes = {} } end
    local saved = cache.modes[mode]
    local ok, records = false, nil
    if saved then mappings = vim.deepcopy(saved)
    else ok, records = pcall(vim.fn.readfile, zig_parser_output_file) end

    if not ok and not saved then
        vim.notify(helpful_message, vim.log.levels.WARN, {
            title = "Mappings",
        })
    end

    if ok then
        for _, line in ipairs(records) do
            local section, syntax, tag, note, description =
                line:match("^([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t(.*)$")

            if section then
                local normal =
                    section == "Normal mode"
                    or section == "Window commands"
                    or section == "Square bracket commands"
                    or section == "Commands starting with 'g'"
                    or section == "Commands starting with 'z'"

                local include =
                    ((mode == "n" or mode == "x" or mode == "s") and normal)
                    or (mode == "o" and normal and (note == "1" or note == "1,2"))
                    or ((mode == "x" or mode == "s" or mode == "o") and section == "Text objects")
                    or ((mode == "x" or mode == "s") and section == "Visual mode")
                    or (mode == "o" and section == "Operator-pending mode")
                    or (mode == "i" and section:match("^Insert mode"))
                    or (mode == "c" and section:match("^Command%-line editing"))
                    or (mode == "t" and section == "Terminal mode")

                local valid =
                    include
                    and tag ~= "count"
                    and syntax ~= ""
                    and syntax ~= "<Space>"
                    and syntax ~= "other"
                    and not syntax:find(" to ", 1, true)
                    and not syntax:find(" - ", 1, true)
                    and not syntax:find(" others", 1, true)
                    and not syntax:match("^Meta characters")
                    and not syntax:match("^{[^}]+}")
                    and syntax ~= "CTRL-[ <Esc>"

                if valid then
                    local arguments = {}

                    for argument in syntax:gmatch("%b{}") do
                        arguments[#arguments + 1] = argument
                    end

                    local key = syntax
                    key = key:gsub('^%["x%]', "")
                    key = key:gsub("%b{}", "")
                    key = key:gsub('^"(`+)"$', "%1")
                    key = key:gsub("CTRL%-SHIFT%-([^%s]+)", "<C-S-%1>")
                    key = key:gsub("CTRL%-<([^>]+)>", "<C-%1>")
                    key = key:gsub("CTRL%-([^%s]+)", "<C-%1>")
                    key = key:gsub("%s+", "")

                    if key ~= "" then
                        if section == "Normal mode" and (
                                key == "g"
                                or key == "z"
                                or key == "["
                                or key == "]"
                                or key == "<C-W>"
                            ) then
                            description = "Command prefix: " .. description
                        end

                        if #arguments > 0 then
                            description = description
                                .. " (requires "
                                .. table.concat(arguments, ", ")
                                .. ")"
                        end

                        local priority = 1

                        if section:find(" / ", 1, true) then
                            priority = 0
                        elseif section == "Text objects" then
                            priority = 2
                        elseif section == "Visual mode"
                            or section == "Operator-pending mode" then
                            priority = 3
                        end

                        if not priorities[key] or priority > priorities[key] then
                            mappings[key] = {
                                desc = description,
                                help = tag,
                            }
                            priorities[key] = priority
                        elseif priority == priorities[key]
                            and section == "Normal mode"
                            and description ~= mappings[key].desc then
                            mappings[key].desc = mappings[key].desc .. "; " .. description
                        end
                    end
                end
            end
        end
    end

    if not saved and ok then cache.modes[mode] = vim.deepcopy(mappings) end

    for _, map in ipairs(vim.api.nvim_get_keymap(mode)) do
        local key = map.lhs:gsub(" ", "<Space>"):gsub("^<Space>", "<leader>")
        mappings[key] = map
    end

    for _, map in ipairs(vim.api.nvim_buf_get_keymap(0, mode)) do
        local key = map.lhs:gsub(" ", "<Space>"):gsub("^<Space>", "<leader>")
        mappings[key] = map
    end

    local keys = vim.tbl_keys(mappings)
    table.sort(keys)

    local width_key = 0
    for _, key in ipairs(keys) do
        width_key = math.max(width_key, #key)
    end

    local lines = {}

    for _, key in ipairs(keys) do
        local map = mappings[key]
        local description = map.desc

        if not description or description == "" then
            description = (map.rhs and map.rhs ~= "")
                and map.rhs
                or (map.help and ("See :help " .. map.help))
                or "[Lua callback]"
        end

        description = description:gsub("[\r\n]", " ")

        lines[#lines + 1] = string.format(
            " %-" .. width_key .. "s  %s",
            key,
            description
        )
    end

    if #lines == 0 then
        lines = { " No mappings" }
    end

    vim.schedule(function()
        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

        vim.bo[buf].modifiable = false
        vim.bo[buf].bufhidden = "wipe"

        local width = math.min(100, math.max(1, vim.o.columns - 4))
        local height = math.min(#lines, math.max(1, vim.o.lines - 6))

        local win = vim.api.nvim_open_win(buf, true, {
            relative = "editor",
            width = width,
            height = height,
            row = math.floor((vim.o.lines - height) / 2),
            col = math.floor((vim.o.columns - width) / 2),
            style = "minimal",
            border = "rounded",
            title = " " .. mode .. " mappings ",
            title_pos = "center",
        })

        vim.wo[win].wrap = false
        vim.wo[win].cursorline = true

        for _, key in ipairs({ "q", "<Esc>" }) do
            vim.keymap.set("n", key, function()
                if vim.api.nvim_win_is_valid(win) then
                    vim.api.nvim_win_close(win, true)
                end
            end, { buffer = buf, silent = true })
        end
    end)
end

function M.setup(opts)
    opts = opts or {}
    zig_index_parser_file = opts.parser or (vim.fn.stdpath("config") .. "/assets/parse_nvim_runtime_doc_index.zig")
    runtime_doc_index_file = (vim.env.VIMRUNTIME or "") .. "/doc/index.txt"
    zig_parser_output_file = opts.index or (vim.fn.stdpath("config") .. "/assets/output_nvim_runtime_doc_index.txt")
    helpful_message = string.format("Native mapping index is missing.\nRun:\nzig run %s -- %s > %s",
        vim.fn.shellescape(zig_index_parser_file), vim.fn.shellescape(runtime_doc_index_file), vim.fn.shellescape(zig_parser_output_file))
    cache = { stamp = nil, modes = {} }
    vim.api.nvim_create_user_command("MappingIndexReload", function() cache = { stamp = nil, modes = {} } end,
        { desc = "Invalidate cached native mapping documentation" })
    vim.keymap.set({ "n", "x", "s", "o" }, "<leader>m", show_mappings, {
        silent = true,
        desc = "Show current mode mappings",
    })

    for mode, escape in pairs({
        i = "<Esc>",
        c = "<C-c>",
        t = "<C-\\><C-n>",
    }) do
        vim.keymap.set(mode, "<F6>", function()
            show_mappings(mode)
            return escape
        end, {
            expr = true,
            silent = true,
            desc = "Show current mode mappings",
        })
    end
end

return M
