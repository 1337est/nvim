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

-- recursively iterate over each segment separated by '.' to parse extension with multiple dots in filename
local function iterate_multi_dotted_extension(name, icon_table)
  if not name then
    return nil
  end

  local compound_ext = name:match "%.(.*)"
  local icon = icon_table[compound_ext]
  if icon then
    return icon
  end

  return iterate_multi_dotted_extension(compound_ext, icon_table)
end

local function get_icon_by_extension(name, ext)
  if ext ~= nil then
    return icons_by_file_extension[ext] or icons[ext]
  end
  return iterate_multi_dotted_extension(name, icons_by_file_extension)
end

local function get_icon_data(name, ext, opts)
  if type(name) == "string" then
    name = name:lower()
  end

  opts = opts or {}
  local use_default = opts.default ~= false -- default true if nil

  local icon_data = icons_by_filename[name] or icons[name] or get_icon_by_extension(name, ext)
  if not icon_data and use_default then
    icon_data = default_icon
  end

  return icon_data
end

function M.get_icon(name, ext, opts)
  local icon_data = get_icon_data(name, ext, opts)
  if icon_data then
    return icon_data.icon, get_highlight_name(icon_data)
  end
end

function M.get_icon_by_filetype(ft, opts)
  local name = filetypes[ft]
  return M.get_icon(name or "", nil, opts)
end

-- Initial load
refresh_icons()
M.set_up_highlights()

-- Keep icons in sync if background changes
vim.api.nvim_create_autocmd("OptionSet", {
  pattern = "background",
  callback = function()
    refresh_icons()
    M.set_up_highlights()
  end,
})

-- highlight test command, to see what's working and how things look
vim.api.nvim_create_user_command("NvimWebDeviconsHiTest", function()
  require("nvim-web-devicons.hi-test")(
    default_icon,
    icons_by_filename,
    icons_by_file_extension,
    icons_by_operating_system,
    icons_by_desktop_environment,
    icons_by_window_manager
  )
end, { desc = "nvim-web-devicons: highlight test", })

return M
