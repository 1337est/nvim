return {
    "norcalli/nvim-colorizer.lua",
    config = function()
        -- The documentation on this kinda sucks
        require("colorizer").setup(
        -- 1st table: list of filetypes
        -- 2nd table: list of default options from the plugin page
            { '*' },                     -- all filetypes
            {
                RGB      = true,         -- #FF0 hex codes
                RRGGBB   = true,         -- #FF0000 hex codes
                names    = false,        -- "Name" codes like blue
                RRGGBBAA = false,        -- #RRGGBBAA hex codes
                rgb_fn   = false,        -- CSS rgb() and rgba() functions
                hsl_fn   = false,        -- CSS hsl() and hsla() functions
                css      = false,        -- Enable all CSS features: rgb_fn, hsl_fn, names, RGB, RRGGBB
                css_fn   = false,        -- Enable all CSS *functions*: rgb_fn, hsl_fn
                -- Available modes: foreground, background
                mode     = 'background', -- Set the display mode.
            }
        )
    end,
}
