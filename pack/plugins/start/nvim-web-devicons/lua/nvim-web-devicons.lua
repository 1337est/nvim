local M = {}

-- filetype -> icon name
local filetypes = require "nvim-web-devicons.filetypes"

-- master tables
local icons
local icons_by_filename
local icons_by_file_extension
local icons_by_operating_system
local icons_by_desktop_environment
local icons_by_window_manager

---@class Icon
---@field icon string Nerd-font glyph
---@field color string Hex color code
---@field cterm_color string cterm color code
---@field name string Name of the icon

---@type Icon
local default_icon = {
  icon = "",
  color = "#6d8086",
  cterm_color = "66",
  name = "Default",
}

-- Remove if working without
local global_opts = {
  strict = false,
  default = false,
  color_icons = true,
  variant = nil,
  blend = nil,
}

---Change all keys in a table to lowercase
---Remove entry when lowercase entry already exists
---@param t table
local function lowercase_keys(t)
  if not t then return end

  for k, v in pairs(t) do
    if type(k) == "string" then
      local lower_k = k:lower()
      if lower_k ~= k then
        if not t[lower_k] then
          t[lower_k] = v
        end
        t[k] = nil
      end
    end
  end
end

-- Set the current icons tables, depending on variant option, then &background
local function refresh_icons()
  local theme
  if vim.o.background == "light" then
    theme = require "nvim-web-devicons.icons-light"
  else
    theme = require "nvim-web-devicons.icons-default"
  end

  icons_by_filename = theme.icons_by_filename
  icons_by_file_extension = theme.icons_by_file_extension
  icons_by_operating_system = theme.icons_by_operating_system
  icons_by_desktop_environment = theme.icons_by_desktop_environment
  icons_by_window_manager = theme.icons_by_window_manager

  -- filename matches are case insensitive
  lowercase_keys(icons_by_filename)

  icons = vim.tbl_extend(
    "keep",
    {},
    icons_by_filename,
    icons_by_file_extension,
    icons_by_operating_system,
    icons_by_desktop_environment,
    icons_by_window_manager
  )
  -- stash the default under numeric key for easy access in iterations
  icons[1] = default_icon
end

local function get_highlight_name(icon_data)
  return icon_data.name and ("DevIcon" .. icon_data.name) or nil
end

local function set_up_highlight(icon_data)
  local hl_group = get_highlight_name(icon_data)
  if not hl_group then return end

  if icon_data.color or icon_data.cterm_color then
    vim.api.nvim_set_hl(0, hl_group, {
      fg = icon_data.color,
      ctermfg = tonumber(icon_data.cterm_color),
    })
  end
end

function M.set_up_highlights()
  set_up_highlight(default_icon)

  for _, icon_data in pairs(icons) do
    if icon_data ~= default_icon then
      set_up_highlight(icon_data)
    end
  end
end

local function get_highlight_foreground(icon_data)
  if not global_opts.color_icons then
    icon_data = default_icon
  end

  local higroup = get_highlight_name(icon_data)

  local fg
  if vim.fn.has "nvim-0.9" == 1 then
    fg = vim.api.nvim_get_hl(0, { name = higroup, link = false }).fg
  else
    fg = vim.api.nvim_get_hl_by_name(higroup, true).foreground ---@diagnostic disable-line: deprecated
  end

  return string.format("#%06x", fg)
end

local function get_highlight_ctermfg(icon_data)
  if not global_opts.color_icons then
    icon_data = default_icon
  end

  local higroup = get_highlight_name(icon_data)

  if vim.fn.has "nvim-0.9" == 1 then
    --- @type string
    --- @diagnostic disable-next-line: undefined-field  vim.api.keyset.hl_info specifies cterm, not ctermfg
    return vim.api.nvim_get_hl(0, { name = higroup, link = false }).ctermfg
  else
    return vim.api.nvim_get_hl_by_name(higroup, false).foreground ---@diagnostic disable-line: deprecated
  end
end

local loaded = false

function M.has_loaded()
  return loaded
end

local if_nil = vim.F.if_nil
function M.setup(opts)
  if loaded then
    return
  end

  loaded = true

  opts = opts or {}

  if opts.default then
    global_opts.default = true
  end

  if opts.strict then
    global_opts.strict = true
  end

  global_opts.color_icons = if_nil(opts.color_icons, global_opts.color_icons)

  if opts.variant == "light" or opts.variant == "dark" then
    global_opts.variant = opts.variant
    -- Reload the icons after setting variant option
    refresh_icons()
  end

  if type(opts.blend) == "number" then
    global_opts.blend = opts.blend
  end

  M.set_up_highlights()

  vim.api.nvim_create_autocmd("ColorScheme", {
    desc = "Re-apply icon colors after changing colorschemes",
    group = vim.api.nvim_create_augroup("NvimWebDevicons", { clear = true }),
    callback = M.set_up_highlights,
  })

  -- highlight test command
  vim.api.nvim_create_user_command("NvimWebDeviconsHiTest", function()
    require "nvim-web-devicons.hi-test" (
      default_icon,
      {}, -- no global_opts.override anymore, or try passing nil
      icons_by_filename,
      icons_by_file_extension,
      icons_by_operating_system,
      icons_by_desktop_environment,
      icons_by_window_manager
    )
  end, { desc = "nvim-web-devicons: highlight test", })
end

function M.get_default_icon()
  return default_icon
end

-- recursively iterate over each segment separated by '.' to parse extension with multiple dots in filename
local function iterate_multi_dotted_extension(name, icon_table)
  if name == nil then
    return nil
  end

  local compound_ext = name:match "%.(.*)"
  local icon = icon_table[compound_ext]
  if icon then
    return icon
  end

  return iterate_multi_dotted_extension(compound_ext, icon_table)
end

local function get_icon_by_extension(name, ext, opts)
  local is_strict = if_nil(opts and opts.strict, global_opts.strict)
  local icon_table = is_strict and icons_by_file_extension or icons

  if ext ~= nil then
    return icon_table[ext]
  end

  return iterate_multi_dotted_extension(name, icon_table)
end

local function get_icon_data(name, ext, opts)
  if type(name) == "string" then
    name = name:lower()
  end

  if not loaded then
    M.setup()
  end

  local has_default = if_nil(opts and opts.default, global_opts.default)
  local is_strict = if_nil(opts and opts.strict, global_opts.strict)
  local icon_data
  if is_strict then
    icon_data = icons_by_filename[name] or get_icon_by_extension(name, ext, opts) or (has_default and default_icon)
  else
    icon_data = icons[name] or get_icon_by_extension(name, ext, opts) or (has_default and default_icon)
  end

  return icon_data
end

function M.get_icon(name, ext, opts)
  local icon_data = get_icon_data(name, ext, opts)

  if icon_data then
    return icon_data.icon, get_highlight_name(icon_data)
  end
end

function M.get_icon_name_by_filetype(ft)
  return filetypes[ft]
end

function M.get_icon_by_filetype(ft, opts)
  local name = M.get_icon_name_by_filetype(ft)
  opts = opts or {}
  opts.strict = false
  return M.get_icon(name or "", nil, opts)
end

function M.get_icon_colors(name, ext, opts)
  local icon_data = get_icon_data(name, ext, opts)

  if icon_data then
    local color = icon_data.color
    local cterm_color = icon_data.cterm_color
    if icon_data.name and highlight_exists(get_highlight_name(icon_data)) then
      color = get_highlight_foreground(icon_data) or color
      cterm_color = get_highlight_ctermfg(icon_data) or cterm_color
    end
    return icon_data.icon, color, cterm_color
  end
end

function M.get_icon_colors_by_filetype(ft, opts)
  local name = M.get_icon_name_by_filetype(ft)
  return M.get_icon_colors(name or "", nil, opts)
end

function M.get_icon_color(name, ext, opts)
  local data = { M.get_icon_colors(name, ext, opts) }
  return data[1], data[2]
end

function M.get_icon_color_by_filetype(ft, opts)
  local name = M.get_icon_name_by_filetype(ft)
  opts = opts or {}
  opts.strict = false
  return M.get_icon_color(name or "", nil, opts)
end

function M.get_icon_cterm_color(name, ext, opts)
  local data = { M.get_icon_colors(name, ext, opts) }
  return data[1], data[3]
end

function M.get_icon_cterm_color_by_filetype(ft, opts)
  local name = M.get_icon_name_by_filetype(ft)
  return M.get_icon_cterm_color(name or "", nil, opts)
end

-- Load the icons already, the loaded tables depend on the 'background' setting.
refresh_icons()

function M.refresh()
  refresh_icons()
  M.set_up_highlights(true)
end

-- Change icon set on background change
vim.api.nvim_create_autocmd("OptionSet", {
  pattern = "background",
  callback = M.refresh,
})

return M
