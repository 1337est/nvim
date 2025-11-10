-- $Project: Minimal Neovim$
-- $File: init.lua$
-- $Date: 2025-11-05$
-- $Revision: 3$
-- $Author: Adrian Sanchez$
-- $Notice: $

-- PICKUP3: then back to "added later" to see what I'm missing
-- TODO: go through to see if missing any settings, check other people's configs
-- to get an idea of what I'm missing (too many options to remember)
-- notable ones:
-- https://github.com/radleylewis/nvim-lite/blob/master/init.lua
-- https://github.com/nvim-lua/kickstart.nvim/blob/master/init.lua

--------------------------------------------------------------------------------
-- Minimal single-file setup with: LSP, Treesitter, Formatting, Statusline
--------------------------------------------------------------------------------

-- =============== Added Later =================
-- colorscheme via colors/1337dark (onedark inspired)
vim.cmd.colorscheme("1337dark")
vim.api.nvim_set_hl(0, "Normal", { bg = "none" })
vim.api.nvim_set_hl(0, "NormalNC", { bg = "none" })
vim.api.nvim_set_hl(0, "EndOfBuffer", { bg = "none" })

vim.g.mapleader = " "
vim.g.maplocalleader = " "
vim.g.have_nerd_font = true

vim.opt.cursorline = true
vim.opt.wrap = false
vim.opt.linebreak = true
vim.opt.guicursor = ""
vim.opt.colorcolumn = "80"
vim.opt.completeopt = "menuone,noinsert,noselect"
vim.opt.pumheight = 10
vim.opt.pumblend = 10
vim.opt.winblend = 10
vim.opt.conceallevel = 0
vim.opt.concealcursor = ""
vim.opt.lazyredraw = true
vim.opt.list = true
vim.opt.listchars = {
    tab = "<->", trail = ".", nbsp = "-",
}
vim.opt.backup = false
vim.opt.writebackup = false
vim.opt.swapfile = false
vim.opt.undofile = true
vim.opt.undodir = vim.fn.stdpath("state") .. "/undodir//"
vim.opt.autoread = true
vim.opt.autowrite = false
vim.opt.autochdir = false
vim.opt.mouse = "a"
vim.opt.mousescroll = "ver:1,hor:1"
vim.opt.iskeyword:append("-")
vim.opt.showtabline = 2
-- vim.opt.winbar =

-- PICKUP2: All of ssh next
--------------------------------------------------------------------------------
-- SSH / Remote helpers (netrw + terminal)
--------------------------------------------------------------------------------

--- Build a netrw scp/sftp URI from host and path.
--- @param host string   -- "user@host" or "host"
--- @param path? string  -- ""/nil => remote home; startswith "/" => absolute
--- @param scheme? "scp"|"sftp"
--- @return string
local function _ssh_uri(host, path, scheme)
    scheme = scheme or "scp"
    path = path or ""
    if path == "" then                -- remote home
        return ("%s://%s"):format(scheme, host)
    elseif path:sub(1, 1) == "/" then -- absolute
        return ("%s://%s//%s"):format(scheme, host, path:gsub("^/*", ""))
    else                              -- home-relative
        return ("%s://%s/%s"):format(scheme, host, path)
    end
end

--- Explore a remote directory using netrw.
--- @param host string
--- @param path? string
--- @param scheme? "scp"|"sftp"
local function ssh_browse(host, path, scheme)
    vim.cmd("Explore " .. _ssh_uri(host, path, scheme))
end

--- Edit a remote file using netrw.
--- @param host string
--- @param path string
--- @param scheme? "scp"|"sftp"
local function ssh_edit(host, path, scheme)
    vim.cmd("edit " .. _ssh_uri(host, path, scheme))
end

--- Open an interactive SSH terminal in a right split.
--- @param host string
local function ssh_term(host)
    vim.cmd("vsplit")
    vim.cmd("wincmd l")
    vim.cmd("terminal ssh " .. vim.fn.fnameescape(host))
    vim.cmd("startinsert")
end

-- :SSH [user@]host [path]      -> browse
vim.api.nvim_create_user_command("SSH", function(opts)
    local host = opts.fargs[1]
    local path = opts.fargs[2]
    if not host then
        vim.ui.input(
            { prompt = "host (user@host): " },
            function(h)
                if not h or h == "" then
                    return
                end
                vim.ui.input(
                    { prompt = "path (empty=~): " },
                    function(p)
                        ssh_browse(h, p)
                    end
                )
            end
        )
    else
        ssh_browse(host, path)
    end
end, { nargs = "*", desc = "Browse remote with netrw: :SSH user@host [path]" })

-- :SHEdit [user@]host //abs/or/rel/path -> edit file
vim.api.nvim_create_user_command("SHEdit", function(opts)
    local host, path = opts.fargs[1], opts.fargs[2]
    if not host or not path then
        vim.notify("Usage: :SHEdit user@host //abs/or/rel/path", vim.log.levels.WARN)
        return
    end
    ssh_edit(host, path)
end, { nargs = "+", desc = "Edit remote file via netrw" })

-- :SSHTerm [user@]host -> terminal SSH session
vim.api.nvim_create_user_command("SSHTerm", function(opts)
    local host = opts.fargs[1]
    if not host then
        vim.ui.input(
            { prompt = "host (user@host): " },
            function(h)
                if h and h ~= "" then
                    ssh_term(h)
                end
            end
        )
    else
        ssh_term(host)
    end
end, { nargs = "?", desc = "Open terminal SSH session" })

--- Statusline segment: show remote scheme+host for scp/sftp buffers.
--- @return string
local function stl_remote_host()
    local name = vim.api.nvim_buf_get_name(0)
    local scheme, host = name:match("^(%w+)://([^/]+)/")
    if scheme and host then
        return (" [%s:%s]"):format(scheme, host)
    end
    return ""
end

-- =============== Helpers ===============

--- Quick keymap helper: map('<keys>', func_or_cmd, 'Desc', 'n'|{'n','x'})
--- @param keys string              # lhs, e.g. "<Leader>q"
--- @param func string|function     # rhs command or callback
--- @param desc? string             # description for which key/help
--- @param mode? string|string[]    # mode(s), unspecified defaults to "n"
--- @return nil
local function map(keys, func, desc, mode)
    local opts = { noremap = true, silent = true }
    if desc then opts.desc = desc end
    vim.keymap.set(mode or 'n', keys, func, opts)
end

--- Small augroup helper, clear on resource config
--- @param name string
--- @return integer         # augroup id
local function aug(name)
    return vim.api.nvim_create_augroup("1337." .. name, { clear = true })
end

--- Find project root walking upwards for any given markers
--- @param markers string[]   # filenames/dirs e.g. ".git", "pyproject.toml"
--- @param startpath? string  # starting path; defaults to current buffer path
--- @return string            # resolved root directory
local function find_root(markers, startpath)
    local found = vim.fs.find(markers, {
        upward = true,              -- keep searching upward
        stop = vim.uv.os_homedir(), -- stop at ex. /home/adrian
        path = startpath or vim.api.nvim_buf_get_name(0)
    })
    -- if match found, return first in the list (closest match)
    if #found > 0 then return vim.fs.dirname(found[1]) end
    -- else, return cwd
    return vim.uv.cwd()
end

--- Version-safe check for LSP client's method support
--- @param client vim.lsp.Client
--- @param method string # e.g. vim.lsp.protocol.Methods.textDocument_inlayHint
--- @param bufnr integer
--- @return boolean|nil  # nil if supports_method is absent on old versions
local function client_supports_method(client, method, bufnr)
    if vim.fn.has('nvim-0.11') == 1 then -- neovim >= 0.11
        return client:supports_method(method, bufnr)
    else                                 -- neovim <= 0.10
        return client.supports_method and client.supports_method(method, { bufnr = bufnr })
    end
end

-- =============== Mode ===============

local MODE = {
    -- Normal / Operator-pending (and forced variants)
    n         = "[N]",
    no        = "[NP]",    -- operator-pending
    nov       = "[NP-V]",  -- forced charwise
    noV       = "[NP-VL]", -- forced linewise
    ["no\22"] = "[NP-VB]", -- forced blockwise

    -- Normal via i_CTRL-O / terminal variants
    niI       = "[N->I]",
    niR       = "[N->R]",
    niV       = "[N->Rv]",
    nt        = "[NT]",
    ntT       = "[NT->T]",

    -- Visual / Select-mode via v_CTRL-O
    v         = "[V]",
    vs        = "[V-S]",
    V         = "[VL]",
    Vs        = "[VL-S]",
    ["\22"]   = "[VB]",
    ["\22s"]  = "[VB-S]",

    -- Select modes (char/line/block)
    s         = "[S]",
    S         = "[SL]",
    ["\19"]   = "[SB]", -- Select block <Ctrl-S>

    -- Insert + completions variants
    i         = "[I]",
    ic        = "[I-c]",
    ix        = "[I-cx]",

    -- Replace / Virtual-Replace + completion variants
    R         = "[R]",
    Rc        = "[R-c]",
    Rx        = "[R-cx]",
    Rv        = "[Rv]",
    Rvc       = "[Rv-c]",
    Rvx       = "[Rv-cx]",

    -- Command-line editing variants
    c         = "[C]",
    cr        = "[C-r]",
    cv        = "[Ex]",
    cvr       = "[Ex-r]",

    -- Prompts / external / terminal
    r         = "[Hit]",
    rm        = "[More]",
    ["r?"]    = "[Conf]",
    ["!"]     = "[!]",
    t         = "[T]",
}

--- Render the current mode using MODE mapping with fallbacks
--- @return string      # e.g. The value to the associated key
local function mode_label()
    local m = vim.fn.mode(1)
    return MODE[m] or MODE[m:sub(1, 1)] or ("[" .. m .. "]")
end

-- =============== Filename ===============

--- Resolves a concise buffer filename
--- @return string          # "[No Name]" when unnamed
local function buffer_filename()
    -- % -> current buffer's filename
    -- :~ -> abbreviated $HOME as ~
    -- :. -> makes path relative to cwd if possible
    local name = vim.fn.expand("%:~:.")
    return (name == "" and "[No Name]") or name
end

--- Builds statusline flags like [+], [RO], [NM]
--- @return string          # e.g. help files display [RO,NM]
local function stl_flags()
    local parts = {}
    if vim.bo.modified then parts[#parts + 1] = "+" end
    if vim.bo.readonly then parts[#parts + 1] = "RO" end
    if not vim.bo.modifiable then parts[#parts + 1] = "NM" end
    if #parts == 0 then return "" end
    return " [" .. table.concat(parts, ",") .. "]"
end

--- Resolve a filetype icon (Nerd Font if available, else a simple tag).
--- @param ft string
--- @return string          # The icon associated to the ft
local function ft_icon_for(ft)
    if ft == "" then return "" end
    if vim.g.have_nerd_font then
        local nf = {
            lua = "",
            python = "",
            javascript = "",
            typescript = "",
            html = "",
            css = "",
            json = "",
            markdown = "",
            vim = "",
            sh = "",
            bash = "",
            zsh = "",
            c = "",
            cpp = "",
            rust = "",
            go = "",
            zig = "",
            text = "",
            make = "",
        }
        return nf[ft] or ft
    else
        -- ASCII fallback tags
        local tags = {
            lua = "[LUA]",
            python = "[PY]",
            javascript = "[JS]",
            typescript = "[TS]",
            html = "[HTML]",
            css = "[CSS]",
            json = "[JSON]",
            markdown = "[MD]",
            vim = "[VIM]",
            sh = "[SH]",
            bash = "[SH]",
            zsh = "[SH]",
            c = "[C]",
            cpp = "[C++]",
            rust = "[RS]",
            go = "[GO]",
            zig = "[ZIG]",
            text = "[TXT]",
            make = "[MK]",
        }
        return tags[ft] or ("[" .. ft .. "]")
    end
end

--- Update b:git_branch for a buffer (cached; safe if not a git repo).
--- @param bufnr integer
--- @return nil
local function update_git_branch(bufnr)
    bufnr = bufnr or 0
    local bufname = vim.api.nvim_buf_get_name(bufnr)
    if bufname == "" then
        vim.b[bufnr].git_branch = nil
        return
    end
    -- root finder check for .git repo
    local root = find_root({ ".git" }, bufname)
    if not root or root == "" then
        vim.b[bufnr].git_branch = nil
        return
    end

    -- builds git command as string for getting the current branch
    local cmd = "git -C " .. vim.fn.fnameescape(root) .. " rev-parse --abbrev-ref HEAD"
    -- passes command and grabs output
    local out = vim.fn.systemlist(cmd)
    if vim.v.shell_error == 0 and out and out[1] and out[1] ~= "" then
        vim.b[bufnr].git_branch = out[1]
    else
        vim.b[bufnr].git_branch = nil
    end
end

--- Statusline segment: git branch (with icon) and filetype icon.
--- @return string
local function stl_vcs_ft()
    local parts = {}

    -- git branch (only if available)
    local br = vim.b.git_branch
    if br and br ~= "" then
        local glyph = vim.g.have_nerd_font and "  " or " [git:"
        parts[#parts + 1] = glyph .. (vim.g.have_nerd_font and br or (br .. "]"))
    end

    -- filetype icon / tag
    local ft = vim.bo.filetype
    local icon = ft_icon_for(ft)
    if icon ~= "" then
        parts[#parts + 1] = " " .. icon .. " "
    end

    return table.concat(parts)
end

-- Keep git branch cache fresh on common events
vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost", "FocusGained" }, {
    group = aug("status_git_branch_refresh"),
    callback = function(args) update_git_branch(args.buf) end,
})

-- Seed cache for the current buffer on startup
update_git_branch(0)

_G.MyStatusline    = function()
    local left  = (" %s %s%s%s %s"):format(
        mode_label(),
        buffer_filename(),
        stl_vcs_ft(),
        stl_remote_host(), -- TEST: Need to test
        stl_flags()
    )
    local right = "%l:%c %p%%"
    return left .. " %=" .. right .. " "
end

vim.opt.showmode   = false
vim.opt.laststatus = 3
vim.opt.statusline = "%!v:lua.MyStatusline()"

-- TODO: See if adding syntax can work for custom syntax highlighting as well
-- for instance, TODO in comments etc.

-- =============== Treesitter ===============
-- Try to start Treesitter highlight for this buffer's filetype.
-- If no parser is installed, silently fall back to :syntax enable.
vim.api.nvim_create_autocmd({ "FileType" }, {
    group = aug("ts_auto_start"),
    callback = function(args)
        local ok = pcall(function() vim.treesitter.start(args.buf) end)
        if not ok then
            vim.cmd("syntax enable")
        end
    end,
})

-- =============== Built-in LSP ===============
-- Define a small set of servers to try starting if the executable exists.
-- You can extend this table with your own servers via microsoft's list below:
-- https://microsoft.github.io/language-server-protocol/implementors/servers/
-- TEST: I've installed the packages below on my home system, need to figure
-- out a portable solution so I can get this setup from just my config download
-- Maybe I'll include a build/install script for all of the language servers
-- for a specific OS using either C++ or zig. I think I may want to try zig out
-- for this, as I know that they are working on multi-architype builds with
-- their mantra "build it with zig". Will need to test with this.

-- Setup function for C-family filetypes that all use clangd. The servers table
-- below is searched later by ft, which makes finding a language server easier.
-- TODO: streamline the below ifthen paths to be similar for all lsp's
local function start_clangd(buf)
    if vim.fn.executable("clangd") ~= 1 then
        vim.notify("LSP: clangd not found in $PATH", vim.log.levels.ERROR)
        return
    end
    local root = find_root(
        { "compile_commands.json", "compile_flags.txt", ".git" },
        vim.api.nvim_buf_get_name(buf))
    vim.lsp.start({
        name = "clangd",
        cmd = { "clangd", "--background-index", "--clang-tidy" },
        root_dir = root,
        single_file_support = true,
        -- TODO: add capabilities here
    }, { bufnr = buf })
end

local servers = {
    -- 1. lua ft
    -- On arch: sudo pacman -S --needed lua-language-server
    -- On windows: TODO: add command setup
    -- On ubuntu: TODO: add command setup
    -- https://github.com/LuaLS/lua-language-server?tab=readme-ov-file
    lua = function(buf)
        if vim.fn.executable("lua-language-server") == 1 then
            local root = find_root(
                { ".luarc.json", ".git" },
                vim.api.nvim_buf_get_name(buf))
            vim.lsp.start({
                name = "lua_ls",
                cmd = { "lua-language-server" },
                root_dir = root,
                single_file_support = true,
                settings = {
                    Lua = {
                        diagnostics = { globals = { "vim" } },
                        workspace   = { checkThirdParty = false },
                        telemetry   = { enable = false },
                    }
                },
            }, { bufnr = buf })
        else
            vim.notify("LSP: lua-language-server not found in $PATH", vim.log.levels.ERROR)
        end
    end,

    -- 2. zig ft
    -- On arch: sudo pacman -S --needed zls
    -- On windows: TODO: add command setup
    -- On ubuntu: TODO: add command setup
    -- https://github.com/zigtools/zls
    zig = function(buf)
        if vim.fn.executable("zls") == 1 then
            local root = find_root(
                { "zls.json", ".git" },
                vim.api.nvim_buf_get_name(buf))
            vim.lsp.start({
                name = "zls",
                cmd = { "zls" },
                root_dir = root,
                single_file_support = true,
            }, { bufnr = buf })
        else
            vim.notify("LSP: zls not found in $PATH", vim.log.levels.ERROR)
        end
    end,

    -- 3. c, cpp, objc, objcpp
    -- On arch: sudo pacman -S --needed clangd
    -- On windows: TODO: add commands setup
    -- On ubuntu: TODO: add commands setup
    -- https://github.com/llvm/llvm-project/tree/main/clang-tools-extra/clangd
    -- https://clangd.llvm.org/
    c = start_clangd,
    cpp = start_clangd,
    objc = start_clangd,
    objcpp = start_clangd,

    -- 4. sudo pacman -S --needed gopls
    -- https://github.com/golang/tools/tree/master/gopls
    go = function(buf)
        if vim.fn.executable("gopls") == 1 then
            local root = find_root(
                { "go.work", "go.mod", ".git" },
                vim.api.nvim_buf_get_name(buf))
            vim.lsp.start({
                name                = "gopls",
                cmd                 = { "gopls" },
                root_dir            = root,
                single_file_support = true,
                settings            = {
                    gopls = {
                        usePlaceholders = true,
                        analyses = { unusedparams = true, shadow = true },
                        staticcheck = true,
                    },
                },
            }, { bufnr = buf })
        else
            vim.notify("LSP: gopls not found in $PATH", vim.log.levels.ERROR)
        end
    end,

    -- 5. sudo pacman -S --needed rust-analyzer
    -- https://github.com/rust-lang/rust-analyzer
    rust = function(buf)
        if vim.fn.executable("rust-analyzer") == 1 then
            local root = find_root(
                { "Cargo.toml", ".git" },
                vim.api.nvim_buf_get_name(buf))
            vim.lsp.start({
                name                = "rust_analyzer",
                cmd                 = { "rust-analyzer" },
                root_dir            = root,
                single_file_support = true,
                settings            = {
                    ["rust-analyzer"] = {
                        cargo = { allFeatures = true },
                        check = { command = "clippy" },
                    },
                },
            }, { bufnr = buf })
        else
            vim.notify("LSP: rust-analyzer not found in $PATH", vim.log.levels.ERROR)
        end
    end,
}

-- Autostart above servers when a matching filetype opens
vim.api.nvim_create_autocmd({ "FileType" }, {
    group = aug("lsp_auto_start"),
    callback = function(args)
        local ft = vim.bo[args.buf].filetype
        local starter = servers[ft]
        if starter then pcall(starter, args.buf) end
    end,
})

-- LSP on_attach: keys, highlights, inlay hints, format-on-save
vim.api.nvim_create_autocmd("LspAttach", {
    group = aug("lsp_on_attach"),
    callback = function(event)
        local bufnr  = event.buf
        local client = vim.lsp.get_client_by_id(event.data.client_id)

        -- Keymaps (no plugins)
        map("grn", vim.lsp.buf.rename, "LSP: Rename", "n")
        map("gra", vim.lsp.buf.code_action, "LSP: Code Action", { "n", "x" })
        map("grd", vim.lsp.buf.definition, "LSP: Goto Definition", "n")
        map("grD", vim.lsp.buf.declaration, "LSP: Goto Declaration", "n")
        map("grr", vim.lsp.buf.references, "LSP: References", "n")
        map("gri", vim.lsp.buf.implementation, "LSP: Implementation", "n")
        map("K", vim.lsp.buf.hover, "LSP: Hover", "n")
        map("gtd", vim.lsp.buf.type_definition, "LSP: Type Definition", "n")
        map("[d", vim.diagnostic.goto_prev, "Diag: Previous", "n")
        map("]d", vim.diagnostic.goto_next, "Diag: Next", "n")
        map("<leader>e", vim.diagnostic.open_float, "Diag: Float", "n")
        map("<leader>q", vim.diagnostic.setloclist, "Diag: Loclist", "n")

        -- Inlay hints toggle (if supported)
        if client and client_supports_method(client, vim.lsp.protocol.Methods.textDocument_inlayHint, bufnr) then
            map("<leader>th", function()
                local enabled = vim.lsp.inlay_hint.is_enabled({ bufnr = bufnr })
                vim.lsp.inlay_hint.enable(not enabled, { bufnr = bufnr })
            end, "LSP: Toggle Inlay Hints", "n")
        end

        -- Document highlight (if supported)
        if client and client_supports_method(client, vim.lsp.protocol.Methods.textDocument_documentHighlight, bufnr) then
            local hlgroup = aug("lsp_doc_highlight")
            vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
                group = hlgroup, buffer = bufnr, callback = vim.lsp.buf.document_highlight,
            })
            vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI", "BufLeave" }, {
                group = hlgroup, buffer = bufnr, callback = vim.lsp.buf.clear_references,
            })
        end

        -- Format on save (if supported)
        if client and client_supports_method(client, vim.lsp.protocol.Methods.textDocument_formatting, bufnr) then
            local fmtgrp = aug(("lsp_format_%d"):format(bufnr))
            vim.api.nvim_create_autocmd("BufWritePre", {
                group = fmtgrp,
                buffer = bufnr,
                callback = function()
                    -- filter: prefer the attached client for this buffer
                    vim.lsp.buf.format({ bufnr = bufnr, timeout_ms = 1500 })
                end,
            })
        end
    end,
})

-- Manual format key (works even if you disabled format-on-save above)
map("<leader>f", function()
    vim.lsp.buf.format({ async = false, timeout_ms = 1500 })
end, "LSP: Format buffer", "n")

-- =============== Sensible defaults ===============

-- Search UX
vim.opt.ignorecase = true
vim.opt.smartcase  = true
vim.opt.incsearch  = true
vim.opt.hlsearch   = true
map("<Esc>", "<cmd>nohlsearch<CR>", "Clear search highlight", "n")

-- Split behavior
vim.opt.splitright     = true
vim.opt.splitbelow     = true
vim.opt.inccommand     = "split"

-- UI bits
vim.opt.number         = true
vim.opt.relativenumber = true
vim.opt.signcolumn     = "yes"
vim.opt.termguicolors  = true
vim.opt.updatetime     = 300
vim.opt.timeoutlen     = 500

-- Indent / text
vim.opt.expandtab      = true
vim.opt.shiftwidth     = 4
vim.opt.tabstop        = 4
vim.opt.smartindent    = true

-- Clipboard (optional)
vim.schedule(function() vim.opt.clipboard = "unnamedplus" end)
vim.api.nvim_create_autocmd("TextYankPost", {
    desc = "Brief highlight on yank",
    group = aug("hl_on_yank"),
    pattern = "*",
    callback = function()
        vim.hl.on_yank({
            higroup = "IncSearch",
            timeout = 40,
        })
    end,
})

-- Remove auto comment continuation
vim.api.nvim_create_autocmd("BufEnter", {
    group = aug("format_opts_remove_cro"),
    callback = function() vim.opt.formatoptions:remove({ "c", "r", "o" }) end,
})

-- Viewdir/folds
vim.opt.viewdir = vim.fn.stdpath("state") .. "/viewdir//"
vim.opt.foldcolumn = "1"
vim.opt.foldmethod = "indent" -- TEST: previously "expr" with treesitter, so far LOVING it with foldlevel = 99
-- vim.opt.foldexpr = "nvim_treesitter#foldexpr()"
vim.opt.foldlevel = 99
vim.api.nvim_create_autocmd("BufWinLeave", {
    desc = "Remember folds on window leave",
    group = aug("fold_remember_on_leave"),
    pattern = "*.*",
    command = "mkview",
})
vim.api.nvim_create_autocmd("BufWinEnter", {
    desc = "Remember folds on window enter",
    group = aug("fold_remember_on_enter"),
    pattern = "*.*",
    command = "silent! loadview",
})

--------------------------------------------------------------------------------
-- Which-key-like popup (no plugins)
--------------------------------------------------------------------------------

-- Small UI helper: open a centered floating window with lines
-- @param lines string[]
-- @param title string
-- @return number win_id, number buf
local function _open_popup(lines, title)
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
    vim.api.nvim_buf_set_option(buf, "modifiable", false)
    vim.api.nvim_buf_set_option(buf, "filetype", "help") -- nice highlighting for headers

    -- Compute width/height from content
    local width = 0
    for _, l in ipairs(lines) do
        local w = vim.fn.strdisplaywidth(l)
        if w > width then width = w end
    end
    local height = math.max(1, #lines)

    local maxw   = math.floor(vim.o.columns * 0.9)
    local maxh   = math.floor(vim.o.lines * 0.8)
    width        = math.min(width + 2, maxw)
    height       = math.min(height + 2, maxh)

    local row    = math.floor((vim.o.lines - height) / 2 - 1)
    local col    = math.floor((vim.o.columns - width) / 2)

    local win    = vim.api.nvim_open_win(buf, true, {
        relative = "editor",
        style = "minimal",
        border = "rounded",
        row = row,
        col = col,
        width = width,
        height = height,
        title = title,
        title_pos = "center",
    })

    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.api.nvim_set_option_value("winblend", vim.o.winblend or 10, { win = win })
    -- Close on q / <Esc> in the popup
    vim.keymap.set("n", "q", function() pcall(vim.api.nvim_win_close, win, true) end,
        { buffer = buf, nowait = true, silent = true })
    vim.keymap.set("n", "<Esc>", function() pcall(vim.api.nvim_win_close, win, true) end,
        { buffer = buf, nowait = true, silent = true })

    return win, buf
end

-- Expand <leader> for nice display
-- @param lhs string
-- @return string
local function _pretty_lhs(lhs)
    local leader = vim.g.mapleader or "\\"
    return lhs:gsub("<[Ll]eader>", leader)
end

-- Collect active mappings in a mode (global + buffer), optionally filter by prefix
-- @param mode string  -- "n", "x", etc.
-- @param prefix? string  -- e.g. "<leader>g"
-- @return table[{lhs=string, desc=string, buffer=boolean}]
local function _collect_maps(mode, prefix)
    local seen = {}
    local out = {}
    local function add(m, is_buf)
        if m.noremap == 1 and m.lhs ~= "" then
            if not prefix or _pretty_lhs(m.lhs):find("^" .. vim.pesc(_pretty_lhs(prefix))) then
                local key = mode .. "\0" .. m.lhs .. "\0" .. tostring(is_buf)
                if not seen[key] then
                    seen[key] = true
                    local desc = m.desc or (m.rhs and (m.rhs:gsub("\n", " "))) or ""
                    table.insert(out, { lhs = m.lhs, desc = desc, buffer = is_buf or false })
                end
            end
        end
    end

    -- Global maps
    for _, m in ipairs(vim.api.nvim_get_keymap(mode)) do add(m, false) end
    -- Buffer-local maps (current buffer)
    for _, m in ipairs(vim.api.nvim_buf_get_keymap(0, mode)) do add(m, true) end

    table.sort(out, function(a, b) return a.lhs < b.lhs end)
    return out
end

-- Curated Vim/Neovim built-in cheat sheet (normal mode highlights)
-- Not exhaustive; for full list use :help index
local VIM_DEFAULTS = {
    { "Motions",
        {
            { "h j k l",     "left/down/up/right" },
            { "w/W b/B e/E", "word/WORD forward/back; end" },
            { "0 ^ $",       "line start (column 1)/first nonblank/end" },
            { "gg G",        "file start / file end" },
            { "f{ch}/t{ch}", "find char / till char (;/, to repeat)" },
            { "%",           "jump to matching pair" },
            { "{ }",         "paragraph (blank-line delimited)" },
            { ")",           "next sentence (and ( prev)" },
        }
    },
    { "Operators",
        {
            { "d",  "delete (cut)" }, { "c", "change" }, { "y", "yank (copy)" },
            { "g~", "swap case" }, { "gu/gU", "lower/UPPER" }, { "=", "format" },
            { ">", "indent" }, { "<", "outdent" },
        }
    },
    { "Search & Marks",
        {
            { "/ ? n N", "search forward/back; next/prev" },
            { "* #",     "search word under cursor forward/back" },
            { "m{a-z}",  "set mark; '{a-z} to jump" },
        }
    },
    { "Windows/Tabs",
        {
            { "<C-w> s/v",     "split horizontal/vertical" },
            { "<C-w> h/j/k/l", "move across windows" },
            { "gt/gT",         "next/prev tab" },
        }
    },
    { "Folds (indent/marker)",
        {
            { "za", "toggle fold" }, { "zc/zo", "close/open" }, { "zM/zR", "close all/open all" },
        }
    },
    { "g-commands",
        {
            { "gd/gD", "go to definition (LSP overrides)" },
            { "gi",    "go to last insert location" },
            { "gx",    "open url/file under cursor" },
        }
    },
    { "z-commands",
        {
            { "zz", "center line" }, { "zt/zb", "cursor line to top/bottom" },
            { "zi", "toggle foldenable" },
        }
    },
}

-- Format the cheat sheet into lines
-- @param prefix? string
-- @return string[]
local function _build_lines(prefix)
    local lines = {}

    local function add(s) lines[#lines + 1] = s end
    local function pad(s, n) return s .. string.rep(" ", math.max(0, n - vim.fn.strdisplaywidth(s))) end

    -- 1) Built-in (curated)
    add("Vim/Neovim built-ins (curated):")
    for _, group in ipairs(VIM_DEFAULTS) do
        add(("  ▸ %s"):format(group[1]))
        for _, row in ipairs(group[2]) do
            local lhs, desc = row[1], row[2]
            add(("    %s  —  %s"):format(pad(lhs, 18), desc))
        end
    end
    add("")

    -- 2) Active mappings (your maps + any plugin maps), filtered by prefix if provided
    local header = prefix and ("Active mappings (prefix = %q):"):format(prefix) or "Active mappings:"
    add(header)
    local maps = _collect_maps("n", prefix)
    if #maps == 0 then
        add("  (none)")
    else
        add(("  %s  %s  %s"):format(pad("Keys", 22), pad("Description", 40), "Scope"))
        add(("  %s  %s  %s"):format(pad(string.rep("─", 4), 22), pad(string.rep("─", 11), 40), string.rep("─", 5)))
        for _, m in ipairs(maps) do
            local lhs = _pretty_lhs(m.lhs)
            local desc = (m.desc ~= "" and m.desc) or "(no desc)"
            local scope = m.buffer and "buf" or "global"
            add(("  %s  %s  %s"):format(pad(lhs, 22), pad(desc, 40), scope))
        end
    end

    add("")
    add("Hints: type :help index for exhaustive defaults • :help map.txt for mapping docs")
    if prefix then
        add(("       Showing only mappings that start with %q."):format(_pretty_lhs(prefix)))
    end

    return lines
end

-- Show the popup; optional prefix filter (example: "<leader>g")
-- @param prefix? string
local function show_keys_popup(prefix)
    local lines = _build_lines(prefix)
    _open_popup(lines, "Keybindings Cheat Sheet")
end

-- :Keys [prefix] command
vim.api.nvim_create_user_command("Keys", function(opts)
    local prefix = table.concat(opts.fargs, " ")
    if prefix == "" then prefix = nil end
    show_keys_popup(prefix)
end, { nargs = "*", desc = "Show keybindings popup. Optional prefix filter, e.g. :Keys <leader>g" })

-- Map a convenient trigger (your request was g<leader>)
map("g<leader>", function()
    -- Optional: prompt for a prefix to filter your mappings
    vim.ui.input({ prompt = "Filter by prefix (optional, e.g. <leader>g): " }, function(ans)
        show_keys_popup(ans ~= "" and ans or nil)
    end)
end, "Show keybindings popup", "n")
