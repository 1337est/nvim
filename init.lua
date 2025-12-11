-- My initial config
require("init.set")
require("init.map")
require("init.cmd")
require("init.diagnostic")
require("init.lsp")

-- Plugin like things that I've written
require("plugins.leet.floaterminal")
require("plugins.leet.highlighter")
require("plugins.utils")

-- Plugins using a plugin manager (has a separate init.lua)
require("plugins.lazy")
