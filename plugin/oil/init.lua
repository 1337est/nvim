require("oil").setup()

local utils = require("utils")
local map = utils.map
-- File Explorering
map({ mode = "n", keys = "<leader>e", owner = "OIL", desc = "Explorer", fn = ":Oil<CR>" })
