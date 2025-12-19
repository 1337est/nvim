return {
    "nvim-lualine/lualine.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
        require("lualine").setup {
            options = {
                icons_enabled = true,
                theme = 'monokai-pro',
                component_separators = { left = "│", right = "│" },
                section_separators = { left = '', right = '' },
                disabled_filetypes = {
                    statusline = {},
                    winbar = {},
                },
                ignore_focus = {},
                always_divide_middle = true,
                always_show_tabline = true,
                globalstatus = true,
                refresh = {
                    statusline = 1000,
                    tabline = 1000,
                    winbar = 1000,
                    refresh_time = 16, -- ~60fps
                    events = {
                        'WinEnter',
                        'BufEnter',
                        'BufWritePost',
                        'SessionLoadPost',
                        'FileChangedShellPost',
                        'VimResized',
                        'Filetype',
                        'CursorMoved',
                        'CursorMovedI',
                        'ModeChanged',
                    },
                }
            },

            -- STATUSLINE ------------------------------------------------------
            sections = {
                lualine_a = { 'mode' },
                lualine_b = { 'branch', 'diff', 'diagnostics' },
                lualine_c = { {
                    'filename',
                    path = 1, -- 0 -> 4
                } },
                lualine_x = {
                    {
                        'filetype',
                        colored = false, -- Displays filetype icon in color if set to true
                        icon_only = false, -- Display only an icon for filetype
                        icon = { align = 'right' }, -- Display filetype icon on the right hand side
                    },
                },
                lualine_y = { 'hostname' },
                lualine_z = {
                    function()
                        local l = vim.fn.line(".")
                        local L = vim.fn.line("$")
                        local c = vim.fn.col(".")
                        local p = 0

                        if L > 0 then
                            p = math.floor((l / L) * 100)
                        end

                        -- "[%l/%L],%c %3p%%"
                        return string.format("[%d/%d],%d %3d%%%%", l, L, c, p)
                    end,
                }
            },
            inactive_sections = {
                lualine_a = {},
                lualine_b = {},
                lualine_c = {},
                lualine_x = {},
                lualine_y = {},
                lualine_z = {},
            },

            -- WINBAR ----------------------------------------------------------
            winbar = {
                lualine_a = { {
                    'filename',
                    path = 4,
                } },
                lualine_b = {},
                lualine_c = {},
                lualine_x = {},
                lualine_y = {},
                lualine_z = { 'branch' },
            },
            inactive_winbar = {
                lualine_a = {},
                lualine_b = {},
                lualine_c = { {
                    'filename',
                    path = 4,
                } },
                lualine_x = { "branch" },
                lualine_y = {},
                lualine_z = {},
            },

            -- TABLINE ---------------------------------------------------------
            tabline = {
                lualine_a = { 'branch' },
                lualine_b = { 'datetime' },
                lualine_c = { 'lsp_status' },
                lualine_x = {},
                lualine_y = {},
                lualine_z = { 'tabs' }
            },

            extensions = { "oil", },

        }
    end,
}
