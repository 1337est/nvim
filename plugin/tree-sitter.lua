-- nvim/plugin/tree-sitter.lua
if vim.g.loaded_builtin_treesitter then return end
vim.g.loaded_builtin_treesitter = true

local uv                        = vim.uv or vim.loop

-- OS + lib extension
local is_win                    = (vim.fn.has('win32') == 1) or (vim.fn.has('win64') == 1)
local lib_ext                   = is_win and 'dll' or 'so'

-- Two canonical roots that are already (or should be) on &rtp:
local roots                     = {
    vim.fn.stdpath('config'), -- e.g. ~/.config/nvim   or  %LocalAppData%\nvim
    (vim.fn.stdpath('data') .. '/site') -- e.g. ~/.local/share/nvim/site  or  %LocalAppData%\nvim-data\site
}

-- Make sure both roots are on runtimepath (idempotent)
for _, r in ipairs(roots) do
    local abs = vim.fn.fnamemodify(r, ':p')
    if not string.find(',' .. vim.o.runtimepath .. ',', ',' .. abs .. ',', 1, true) then
        vim.opt.runtimepath:append(abs)
    end
end

-- Helper to check where a compiled parser lives (purely for diagnostics)
local function find_parser(lang, custom_name)
    local name = (custom_name or lang) .. '.' .. lib_ext
    local tried = {}
    for _, r in ipairs(roots) do
        table.insert(tried, r .. '/parser/' .. name)
    end
    for _, p in ipairs(tried) do
        if uv.fs_stat(p) then return p, tried end
    end
    return nil, tried
end

-- Register a language and (optionally) add a queries dir to &rtp
local function register(lang, opts)
    opts = opts or {}

    -- Map filetypes -> parser language (many times these are identical)
    for _, ft in ipairs(opts.filetypes or { lang }) do
        -- Built-in Neovim API; no plugin required
        vim.treesitter.language.register(opts.langname or lang, ft)
    end

    -- If you vendor queries somewhere, add that location to &rtp
    if opts.queries_dir and uv.fs_stat(opts.queries_dir) then
        vim.opt.runtimepath:append(vim.fn.fnamemodify(opts.queries_dir, ':p'))
    end

    -- Optional: warn if the .so/.dll is missing
    local lib, tried = find_parser(lang, opts.libname)
    if not lib then
        vim.schedule(function()
            vim.notify(
                ('Tree-sitter parser for "%s" not found.\nLooked for:\n  - %s')
                :format(lang, table.concat(tried, '\n  - ')),
                vim.log.levels.WARN
            )
        end)
    end
end

-- === Register the languages you manually install ===
register('nu', { filetypes = { 'nu' } }) -- Nushell
-- register('lua', { filetypes = { 'lua' } }) -- Example: Lua (if you build it yourself)
-- register('rust', { filetypes = {'rust'} }) -- add others as you compile them

-- Auto-start Tree-sitter when entering buffers (safe even if parser missing)
vim.api.nvim_create_autocmd({ 'BufReadPost', 'BufNewFile' }, {
    group = vim.api.nvim_create_augroup('builtin_ts_autostart', { clear = true }),
    pattern = '*',
    callback = function(args)
        -- Infers language from &filetype; falls back gracefully if not installed
        pcall(vim.treesitter.start, args.buf)
    end,
})
