local M = {}

--- @brief augroup helper, clears resets autocmds when re-sourcing config
--- @param _owner string
--- @param _group string
--- @return integer         # augroup id
function M.augroup(_owner, _group)
    if type(_owner) ~= "string" or type(_group) ~= "string" then
        error("augroup(): owner and group must be strings")
    end
    return vim.api.nvim_create_augroup(_owner .. "." .. _group, { clear = true })
end

function M.autocmd(args)
  assert(type(args) == "table", "autocmd() expects a table")

  local event   = args.event  or error("Missing 'event' in autocmd()")
  local owner   = args.owner  or error("Missing 'owner' in autocmd()")
  local group   = args.group  or error("Missing 'group' in autocmd()")
  local desc    = args.desc   or error("Missing 'desc' in autocmd()")
  local patbuf = args.patbuf or error("Missing 'patbuf' in autocmd()")

  local opts = {}

  if type(patbuf) == "number" then
      opts.buffer = args.patbuf
  else
    opts.pattern = args.patbuf
  end

  if args.callback and args.command then
    error("autocmd(): Include 'callback' or 'command', you provided both")
  elseif not args.callback and not args.command then
    error("autocmd(): Include 'callback' or 'command', you didn't provide either.")
  end

opts.desc   = ("%s: %s"):format(owner, desc)
opts.once    = args.once   -- defaults to false
opts.nested  = args.nested -- defaults to false

  if group ~= nil then
    local t = type(group)
    if t == "string" then
      opts.group = M.augroup(owner, group) -- use module augroup helper
    elseif t == "number" then
      opts.group = group -- existing group id
    else
      error("autocmd(): 'group' must be string or number")
    end
  end

  if args.callback then
    opts.callback = args.callback
  elseif args.command then
    opts.command = args.command
  end

  return vim.api.nvim_create_autocmd(event, opts)
end

--- Wrapper for vim.keymap.set() to be explicit
--- Ex. Usage:
---   map({
---     mode   = 'n' or { 'n', 'x' },         -- required
---     keys   = '<leader>e',                 -- required
---     owner = '1337',                      -- required (can easily determine who made)
---     desc   = 'Open explorer',             -- required (docs brutha)
---     fn     = my_handler_or_string_rhs,    -- required
---     opts   = { buffer = 0 },              -- optional with default noremap, silent = true
---   })
---
--- Notes:
--- - Validates required fields early (useful during startup).
--- - Merges `opts` with { noremap = true, silent = true } via `"force"`.
--- - Final description becomes `"<owner>: <desc>"` for consistent UX.
function M.map(args)
    assert(type(args) == "table", "map() expects a table")

    local mode = args.mode or error("Missing 'mode' in map()")
    local keys = args.keys or error("Missing 'keys' in map()")
    local owner = args.owner or error("Missing 'owner' in map()")
    local desc = args.desc or error("Missing 'desc' in map()")
    local fn = args.fn or error("Missing 'fn' in map()")

    local opts = vim.tbl_extend("force", {
        noremap = true,
        silent = true,
        desc = ("%s: %s"):format(owner, desc),
    }, args.opts or {})

    vim.keymap.set(mode, keys, fn, opts)
end

return M
