-- The order which I've placed these files is important
-- The first file is for the lazy plugin
require("1337erBoards.lazy")
-- Now I get my personal settings (sets and keymaps) after the plugins. This is
-- important since the plugin may have changed some of the settings.
require('1337erBoards.set')
require("1337erBoards.keymaps")
-- Doesn't matter what order so goes last
require('1337erBoards.autocmd')
