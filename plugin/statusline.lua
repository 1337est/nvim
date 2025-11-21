local MODES = {
    {
        hl = "User1",
        normal = {
            n         = "[N]", -- normal
            no        = "[NP]", -- operator-pending
            nov       = "[NP-V]", -- forced charwise
            noV       = "[NP-VL]", -- forced linewise
            ["no\22"] = "[NP-VB]", -- forced blockwise
            nt        = "[NT]", -- normal terminal
            -- Normal via i_CTRL-O / terminal variants
            niI       = "[N->I]", -- normal back to insert
            niR       = "[N->R]", -- normal back to replace
            niV       = "[N->Rv]", -- normal back to virtual replace
            ntT       = "[NT->T]", -- normal terminal back to Terminal
        },
    },
    {
        hl = "User2",
        visual = {
            -- Visual / Select-mode via v_CTRL-O
            v        = "[V]", -- visual mode
            vs       = "[V-S]", -- visual select
            V        = "[VL]", -- Visual line
            Vs       = "[VL-S]", -- visual select
            ["\22"]  = "[VB]", -- Visual block
            ["\22s"] = "[VB-S]", -- Visual block select
        },
    },
    {
        hl = "User3",
        select = {
            -- Select modes (char/line/block)
            s       = "[S]", -- select
            S       = "[SL]", -- select line
            ["\19"] = "[SB]", -- Select block <Ctrl-S>
        },
    },
    {
        hl = "User4",
        insert = {
            -- Insert + completions variants
            i  = "[I]", -- insert
            ic = "[I-c]", -- insert completion generic
            ix = "[I-cx]", -- insert completion via Ctrl-x
        },
    },
    {
        hl = "User5",
        replace = {
            -- Replace / Virtual-Replace + completion variants
            R   = "[R]", -- replace
            Rc  = "[R-c]", -- replace completion generic
            Rx  = "[R-cx]", -- replace completion via Ctrl-x
            Rv  = "[Rv]", -- virtual replace
            Rvc = "[Rv-c]", -- virtual replace completion generic
            Rvx = "[Rv-cx]", -- virtual replace completion via Ctrl-x
        },
    },
    {
        hl = "User6",
        command = {
            -- Command-line editing variants
            c   = "[C]", -- command
            cr  = "[C-r]", -- command replace
            cv  = "[Ex]", -- command Ex
            cvr = "[Ex-r]", -- command Ex replace
        },
    },
    {
        hl = "User7",
        -- Prompts / external / terminal
        terminal = {
            t = "[T]", -- terminal
        },
    },
    {
        hl = "User1",
        extra = {
            r      = "[Hit]", -- hit enter prompt
            rm     = "[More]", -- -- more-- prompt
            ["r?"] = "[Conf]", -- :confirm query of some sort
            ["!"]  = "[!]", -- Shell or external command is executing
        },
    },
}

-- build mode segment using MODES + User1..User7 hl groups
function _G.StatuslineMode()
    -- non-0 arg gets extendded mode string for extra info
    local cur_mode = vim.fn.mode(1)

    for _, entry in ipairs(MODES) do
        local hl = entry.hl or "User1"

        -- each entry has exactly one of: normal/visual/select/...
        for key, mode_map in pairs(entry) do
            if key ~= "hl" and type(mode_map) == "table" then
                local label = mode_map[cur_mode]
                if label then
                    -- If hl is "UserN", prefer %N* syntax; otherwise use %#Group#
                    local idx = hl:match("^User(%d+)$")
                    if idx then
                        -- -> %1* [N]%*  (highlights with User1)
                        return string.format("%%%s* %s %%* ", idx, label)
                    else
                        -- Fallback: explicit highlight group name
                        return string.format("%%#%s# %s %%* ", hl, label)
                    end
                end
            end
        end
    end

    -- Fallback if we somehow don't know the mode
    return " [?] "
end

local devicons_ok, devicons = pcall(require, "nvim-web-devicons")

function _G.StatuslineIcon()
    if not devicons_ok then
        return ""
    end

    local bufname = vim.api.nvim_buf_get_name(0)
    if bufname == "" then
        return ""
    end

    local fname    = vim.fn.fnamemodify(bufname, ":t")
    local ext      = vim.fn.fnamemodify(bufname, ":e")

    -- default = true ensures we always get *something*
    local icon, hl = devicons.get_icon(fname, ext, { default = true })
    if not icon then
        return ""
    end

    -- If devicons gives us a highlight group, use it
    if hl and hl ~= "" then
        -- %#Group# switches to that hl, %%* resets to previous
        return string.format("%%#%s#%s%%*", hl, icon)
    else
        return icon .. " "
    end
end
