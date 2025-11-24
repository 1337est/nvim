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
                        return string.format("%%%s* %s %%*", idx, label)
                    else
                        -- Fallback: explicit highlight group name
                        return string.format("%%#%s# %s %%*", hl, label)
                    end
                end
            end
        end
    end

    -- Fallback if we somehow don't know the mode
    return " [?] "
end

local icon_hl_cache = {} -- cache derived icon hl groups so we don't recreate them all the time
local devicons_ok, devicons = pcall(require, "nvim-web-devicons")

function _G.StatuslineIcon() -- Gets icons using nvim-web-devicons and displays based on filetype for statusline
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

    local derived

    if hl and hl ~= "" then
        -- reuse if we already created a derived group for this devicon hl
        derived = icon_hl_cache[hl]

        if not derived then
            -- get base highlight (no links)
            local ok_hl, def = pcall(vim.api.nvim_get_hl, 0, { name = hl, link = false })
            if ok_hl and def then
                -- We'll use the devicon's fg as the *background*.
                local base_hex

                if def.bg then
                    base_hex = string.format("#%06x", def.bg)
                elseif def.fg then
                    base_hex = string.format("#%06x", def.fg)
                end

                if base_hex then
                    derived = "StatuslineIcon_" .. hl

                    local spec = {
                        fg = "#000000", -- force black fg
                        bg = base_hex, -- use icon color as bg
                    }

                    if def.ctermfg then
                        spec.ctermbg = def.ctermfg -- approximate in cterm
                    end

                    vim.api.nvim_set_hl(0, derived, spec)
                    icon_hl_cache[hl] = derived
                end
            end
        end
    end

    -- filetype text (what %y/%Y show, roughly)
    local ft = vim.bo.filetype or ""
    if ft == "" then
        ft = "noft"
    end
    ft = ft:upper()

    -- Use derived group if we have one, fall back to original hl, else plain icon
    if derived then
        -- icon + space + filetype, all with derived hl
        return string.format("%%#%s# %s %s %%*", derived, icon, ft)
    elseif hl and hl ~= "" then
        -- icon + filetype with original devicon hl
        return string.format("%%#%s# %s %s %%*", hl, icon, ft)
    else
        -- plain text fallback
        return string.format("%s %s", icon, ft)
    end
end

-- Gets the git indications using gitsigns to display in statusline
function _G.StatuslineGit()
    -- If gitsigns isn't available or not attached, show nothing
    local ok = pcall(require, "gitsigns")
    if not ok then
        return ""
    end

    local dict = vim.b.gitsigns_status_dict
    if not dict or not dict.head or dict.head == "" then
        return ""
    end

    local head    = dict.head
    local added   = dict.added or 0
    local changed = dict.changed or 0
    local removed = dict.removed or 0

    local parts   = {}

    -- branch name
    table.insert(parts, string.format("%%#Title# %s%%*", head))

    -- highlighted diff counts
    if added > 0 then
        table.insert(parts, string.format("%%#DiffAdd#+%d%%*", added))
    end
    if changed > 0 then
        table.insert(parts, string.format("%%#DiffChange#~%d%%*", changed))
    end
    if removed > 0 then
        table.insert(parts, string.format("%%#DiffDelete#-%d%%*", removed))
    end

    -- leading/trailing space so it doesn't clash with neighbors
    return table.concat(parts, "")
end

vim.o.statusline = table.concat({
    "%{%v:lua.StatuslineMode()%}", -- leftmost: mode block
    "%{%v:lua.StatuslineIcon()%}", -- devicon icon
    "%{%v:lua.StatuslineGit()%}", -- git branch + hunks from gitsigns
    "%=", -- right alignment starts
    "[%l/%L],%c %3p%%", -- right: line/LINES,col, percent
})
