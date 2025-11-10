-- $Project: Minimal Neovim$
-- $File: init.lua$
-- $Date: 2025-11-05$
-- $Revision: 3$
-- $Author: Adrian Sanchez$
-- $Notice: $

-- Utils primary (put this in util directory?)

--- keymap helper: map('<keys>', func_or_cmd, 'Desc', 'n'|{'n','x'})
--- @param keys string              # lhs, e.g. "<Leader>q"
--- @param func string|function     # rhs command or callback
--- @param desc? string             # description for which key/help
--- @param mode? string|string[]    # mode(s), unspecified defaults to "n"
--- @return nil
local function keymap(keys, func, desc, mode)
    local opts = { noremap = true, silent = true }
    if desc then opts.desc = desc end
    vim.keymap.set(mode or 'n', keys, func, opts)
end

--- augroup helper, clear on resource config
--- @param name string
--- @return integer         # augroup id
local function aug(name)
    return vim.api.nvim_create_augroup("1337." .. name, { clear = true })
end

--- Find project root walking upwards for any given markers
--- @param markers string[]   # filenames/dirs e.g. ".git", "pyproject.toml"
--- @param startpath? string  # starting path; defaults to current buffer path
--- @return string            # resolved root directory
local function get_root_dir(markers, startpath)
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
local function does_lsp_client_support_method(client, method, bufnr)
    if vim.fn.has('nvim-0.11') == 1 then -- neovim >= 0.11
        return client:supports_method(method, bufnr)
    else                                 -- neovim <= 0.10
        return client.supports_method and client.supports_method(method, { bufnr = bufnr })
    end
end

--- Render the current mode using mode_map mapping with fallbacks
--- @return string      # e.g. The value to the associated key
local function mode_label()
    local curr_mode = vim.fn.mode(1)
    local mode_map  = {
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
    return mode_map[curr_mode] or mode_map[curr_mode:sub(1, 1)] or ("[" .. curr_mode .. "]")
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

--- Builds modification flags like
--- @return string          # e.g. help files display [RO,NM]
local function modify_flags()
    local parts = {}
    if vim.bo.modified then parts[#parts + 1] = "+" end
    if vim.bo.readonly then parts[#parts + 1] = "RO" end
    if not vim.bo.modifiable then parts[#parts + 1] = "NM" end
    if #parts == 0 then return "" end
    return " [" .. table.concat(parts, ",") .. "]"
end

--- Get the absolute name for a buffer (empty string if unnamed)
--- @param bufnr integer|nil
--- @return string
local function get_full_buffpath(bufnr)
    bufnr = bufnr or 0
    return vim.api.nvim_buf_get_name(bufnr) or ""
end

--- Display the buffer's filename
--- @param bufnr integer|nil
--- @return string
local function bufname_display(bufnr)
    bufnr = bufnr or 0
    local name = vim.api.nvim_buf_get_name(bufnr) or ""
    if name == "" then return "[No Name]" end
    if name:match("^%w+://") then
        return name
    end
    return vim.fn.fnamemodify(name, ":~:.")
end

--- Returns the current branch for a git repo
--- If HEAD is detached, returns the short SHA commit
--- @param root string
--- @return string|nil
local function get_curr_branch(root)
    if not root or root == "" then return nil end
    -- 1) Prefer symbolic-ref (quiet) -> branch name (empty if detached)
    local out = vim.fn.systemlist(
        { "git", "-C", root, "symbolic-ref", "--short", "-q", "HEAD" })
    if vim.v.shell_error == 0 and out and out[1] and out[1] ~= "" then
        return out[1]
    end
    -- 2) Fallback: abbrev-ref (may return "HEAD" when detached)
    out = vim.fn.systemlist(
        { "git", "-C", root, "rev-parse", "--abbrev-ref", "HEAD" })
    if vim.v.shell_error == 0 and out and out[1] and out[1] ~= "" and out[1] ~= "HEAD" then
        return out[1]
    end
    -- 3) Detached HEAD: show short SHA
    out = vim.fn.systemlist({ "git", "-C", root, "rev-parse", "--short", "HEAD" })
    if vim.v.shell_error == 0 and out and out[1] and out[1] ~= "" then
        return out[1]
    end
    return nil
end

-- Utils secondary functions

--- Update b:git_branch for a buffer (cached; safe if not a git repo).
--- @param bufnr integer
--- @return nil
local function update_git_branch(bufnr)
    local bufname = get_full_buffpath(bufnr)
    if bufname == "" then
        vim.b[bufnr].git_branch = nil
        return
    end
    -- root finder check for .git repo
    local root = get_root_dir({ ".git" }, bufname)
    if not root or root == "" then
        vim.b[bufnr].git_branch = nil
        return
    end
    vim.b[bufnr].git_branch = get_curr_branch(root)
end

-- Keep git branch cache fresh on common events
vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost", "FocusGained" }, {
    group = aug("status_git_branch_refresh"),
    callback = function(args) update_git_branch(args.buf) end,
})

-- Seed cache for the current buffer on startup
update_git_branch(0)

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

_G.MyStatusline      = function()
    local left  = (" %s %s%s %s"):format(
        mode_label(),
        bufname_display(),
        stl_vcs_ft(),
        modify_flags()
    )
    local right = "%l:%c %p%%"
    return left .. " %=" .. right .. " "
end

-- TODO: go through to see if missing any settings, check other people's configs
-- to get an idea of what I'm missing (too many options to remember)
-- notable ones:
-- https://github.com/radleylewis/nvim-lite/blob/master/init.lua
-- https://github.com/nvim-lua/kickstart.nvim/blob/master/init.lua

-- =============== Sensible defaults ===============

-- global setup
vim.g.mapleader      = " "      -- space as <leader>
vim.g.maplocalleader = " "      -- space as <leader>
vim.g.have_nerd_font = true     -- ttf-jetbrains-mono-nerd
vim.cmd.colorscheme("1337dark") -- check out colors/1337dark.lua

-- Search UX
vim.opt.ignorecase = true
vim.opt.smartcase  = true
vim.opt.incsearch  = true
vim.opt.inccommand = "split"
vim.opt.hlsearch   = true
vim.opt.iskeyword:append("-")
keymap("<Esc>", "<cmd>nohlsearch<CR>", "Clear search highlight", "n")

-- Window split behavior
vim.opt.splitright     = true
vim.opt.splitbelow     = true
-- Floating windows
vim.opt.winblend       = 10

-- UI/UX bits
vim.opt.number         = true
vim.opt.relativenumber = true
vim.opt.signcolumn     = "yes"
vim.opt.termguicolors  = true
vim.opt.guicursor      = ""
vim.opt.lazyredraw     = true
vim.opt.updatetime     = 300
vim.opt.timeoutlen     = 500
vim.opt.mouse          = "a"
vim.opt.mousescroll    = "ver:1,hor:1"
-- Indicator / hl-lines
vim.opt.cursorline     = true
vim.opt.colorcolumn    = "80"
-- Automatic behavior
vim.opt.autoread       = true
vim.opt.autowrite      = false
vim.opt.autochdir      = false

-- Indent / text
vim.opt.expandtab      = true
vim.opt.shiftwidth     = 4
vim.opt.tabstop        = 4
vim.opt.smartindent    = true
-- Text wrap behavior
vim.opt.wrap           = false
vim.opt.linebreak      = true

-- Concealing text
vim.opt.conceallevel   = 0
vim.opt.concealcursor  = ""
vim.opt.list           = true
vim.opt.listchars      = {
    tab = "<->", trail = ".", nbsp = "-",
}

-- Clipboard
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

-- Completions Ctrl-x-Ctrl-o
vim.opt.completeopt = "menuone,noinsert,noselect"
vim.opt.pumheight   = 10
vim.opt.pumblend    = 10

-- Auto inserts
-- Remove auto comment continuation
vim.api.nvim_create_autocmd("BufEnter", {
    group = aug("format_opts_remove_cro"),
    callback = function() vim.opt.formatoptions:remove({ "c", "r", "o" }) end,
})

-- ================= State options =============================================

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

-- undodir
vim.opt.undodir     = vim.fn.stdpath("state") .. "/undodir//"
vim.opt.undofile    = true

-- backups
vim.opt.backup      = false
vim.opt.writebackup = false

-- swapfiles
vim.opt.swapfile    = false

-- =============== Filename ===============

vim.opt.showmode    = false
vim.opt.laststatus  = 3
vim.opt.statusline  = "%!v:lua.MyStatusline()"

-- tabline
vim.opt.showtabline = 2

-- -- winbar
-- vim.opt.winbar      =

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
    local root = get_root_dir(
        { "compile_commands.json", "compile_flags.txt", ".git" },
        get_full_buffpath(buf))
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
            local root = get_root_dir(
                { ".luarc.json", ".git" },
                get_full_buffpath(buf))
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
            local root = get_root_dir(
                { "zls.json", ".git" },
                get_full_buffpath(buf))
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
            local root = get_root_dir(
                { "go.work", "go.mod", ".git" },
                get_full_buffpath(buf))
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
            local root = get_root_dir(
                { "Cargo.toml", ".git" },
                get_full_buffpath(buf))
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
        keymap("grn", vim.lsp.buf.rename, "LSP: Rename", "n")
        keymap("gra", vim.lsp.buf.code_action, "LSP: Code Action", { "n", "x" })
        keymap("grd", vim.lsp.buf.definition, "LSP: Goto Definition", "n")
        keymap("grD", vim.lsp.buf.declaration, "LSP: Goto Declaration", "n")
        keymap("grr", vim.lsp.buf.references, "LSP: References", "n")
        keymap("gri", vim.lsp.buf.implementation, "LSP: Implementation", "n")
        keymap("K", vim.lsp.buf.hover, "LSP: Hover", "n")
        keymap("gtd", vim.lsp.buf.type_definition, "LSP: Type Definition", "n")
        keymap("[d", vim.diagnostic.goto_prev, "Diag: Previous", "n")
        keymap("]d", vim.diagnostic.goto_next, "Diag: Next", "n")
        keymap("<leader>e", vim.diagnostic.open_float, "Diag: Float", "n")
        keymap("<leader>q", vim.diagnostic.setloclist, "Diag: Loclist", "n")

        -- Inlay hints toggle (if supported)
        if client and does_lsp_client_support_method(client, vim.lsp.protocol.Methods.textDocument_inlayHint, bufnr) then
            keymap("<leader>th", function()
                local enabled = vim.lsp.inlay_hint.is_enabled({ bufnr = bufnr })
                vim.lsp.inlay_hint.enable(not enabled, { bufnr = bufnr })
            end, "LSP: Toggle Inlay Hints", "n")
        end

        -- Document highlight (if supported)
        if client and does_lsp_client_support_method(client, vim.lsp.protocol.Methods.textDocument_documentHighlight, bufnr) then
            local hlgroup = aug("lsp_doc_highlight")
            vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
                group = hlgroup, buffer = bufnr, callback = vim.lsp.buf.document_highlight,
            })
            vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI", "BufLeave" }, {
                group = hlgroup, buffer = bufnr, callback = vim.lsp.buf.clear_references,
            })
        end

        -- Format on save (if supported)
        if client and does_lsp_client_support_method(client, vim.lsp.protocol.Methods.textDocument_formatting, bufnr) then
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
keymap("<leader>f", function()
    vim.lsp.buf.format({ async = false, timeout_ms = 1500 })
end, "LSP: Format buffer", "n")
