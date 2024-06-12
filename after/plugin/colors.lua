-- onedark theme setup
-- Changes to default configuration below
-- URL: https://github.com/navarasu/onedark.nvim
require('onedark').setup {
  -- Main options
  style = 'deep',
  transparent = true,
  ending_tildes = true,

  -- Change code style
  -- Options are italic, bold, underline, none
  -- You can configure multiple style with comma separated, For e.g., keywords = 'italic,bold'
  code_style = {
    comments = 'none',
  },

  -- Lualine option
  lualine = {
    transparent = true,
  },
}

-- function to set colorscheme and highlight group
function ColorMeImpressed(color)
  -- colorscheme setup
  color = color or 'onedark'
  vim.cmd.colorscheme(color)

  -- highlight group(
  -- 0 sets highlight group globally
  -- for group name 'Normal"
  -- value set for background = 'none'
  vim.api.nvim_set_hl(0, 'Normal', { bg = 'none' })
  vim.api.nvim_set_hl(0, 'NormalFloat', { bg = 'none' })

end

ColorMeImpressed()
