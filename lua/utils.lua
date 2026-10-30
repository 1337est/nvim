local M = {}

-- mode

M.mode_labels = {
    n = "[N]",
    no = "[NP]",
    nov = "[NP-V]",
    noV = "[NP-VL]",
    ["no\22"] = "[NP-VB]",
    nt = "[NT]",
    niI = "[N->I]",
    niR = "[N->R]",
    niV = "[N->Rv]",
    ntT = "[NT->T]",
    v = "[V]",
    vs = "[V-S]",
    V = "[VL]",
    Vs = "[VL-S]",
    ["\22"] = "[VB]",
    ["\22s"] = "[VB-S]",
    s = "[S]",
    S = "[SL]",
    ["\19"] = "[SB]",
    i = "[I]",
    ic = "[I-c]",
    ix = "[I-cx]",
    R = "[R]",
    Rc = "[R-c]",
    Rx = "[R-cx]",
    Rv = "[Rv]",
    Rvc = "[Rv-c]",
    Rvx = "[Rv-cx]",
    c = "[C]",
    cr = "[C-r]",
    cv = "[Ex]",
    cvr = "[Ex-r]",
    t = "[T]",
    r = "[Hit]",
    rm = "[More]",
    ["r?"] = "[Conf]",
    ["!"] = "[!]",
}

function M.mode_info(raw)
    raw = raw or vim.fn.mode(1)
    local first = raw:sub(1, 1)
    local map, user = "n", 1

    if raw:sub(1, 2) == "no" then
        map = "o"
    elseif first == "v" or first == "V" or first == "\22" then
        map, user = "x", 2
    elseif first == "s" or first == "S" or first == "\19" then
        map, user = "s", 3
    elseif first == "i" then
        map, user = "i", 4
    elseif first == "R" then
        map, user = "i", 5
    elseif first == "c" then
        map, user = "c", 6
    elseif first == "t" then
        map, user = "t", 7
    end

    return {
        raw = raw,
        map = map,
        label = M.mode_labels[raw] or "[?]",
        user = user,
    }
end

return M
