# `nvim -V1 -v`: output below at home computer
```
NVIM v0.11.5
Build type: RelWithDebInfo
LuaJIT 2.1.1762795099
Compilation: /usr/bin/cc -march=x86-64 -mtune=generic -O2 -pipe -fno-plt -fexceptions     -Wp,-D_FORTIFY_SOURCE=3 -Wformat -Werror=format-security     -fstack-clash-protection -fcf-protection     -fno-omit-frame-pointer -mno-omit-leaf-frame-pointer -g -ffile-prefix-map=/build/neovim/src=/usr/src/debug/neovim -flto=auto -O2 -g -flto=auto -fno-fat-lto-objects -Wall -Wextra -pedantic -Wno-unused-parameter -Wstrict-prototypes -std=gnu99 -Wshadow -Wconversion -Wvla -Wdouble-promotion -Wmissing-noreturn -Wmissing-format-attribute -Wmissing-prototypes -fsigned-char -fstack-protector-strong -Wno-conversion -fno-common -Wno-unused-result -Wimplicit-fallthrough -fdiagnostics-color=always  -DUNIT_TESTING -D_GNU_SOURCE -DINCLUDE_GENERATED_DECLARATIONS -DUTF8PROC_STATIC -I/usr/include/luajit-2.1 -I/usr/include -I/build/neovim/src/neovim/build/src/nvim/auto -I/build/neovim/src/neovim/build/include -I/build/neovim/src/neovim/build/cmake.config -I/build/neovim/src/neovim/src

   system vimrc file: "$VIM/sysinit.vim"
  fall-back for $VIM: "/usr/share/nvim"
```
# neovim minimal config. TODO: plugins & TLDR

I've simplified things below, need to add my plugins structure that I have detailed above

General overview of what neovim does: (fill in doc, spell, undo, or any other dirs I'm missing)

```
0.0 ~/.config/nvim/                  # (%LOCALAPPDATA%\nvim on Windows)
│
├─ 1.0 init.lua                      # runs immediately at startup (:help init.lua)
│
├─ 1.* lua/                          # init.lua modules you `require(...)` (:help lua-module-load)
│   ├─ home/{set,keys,cmd,...}.lua   # home default setup, easy to comment in/out in init.lua
│   └─ work/{set,keys,cmd,...}.lua   # work default setup, easy to comment in/out in init.lua
│
├─ 2.0 pack/                         # Vim packages (optional if using a manager)
│  ├─ 2.1 start/                     # added to rtp automatically
│  │   └─ 2.2* <plugin>/             # Each plugin sourced alphabetically, .vim -> .lua
│  │       └─ 2.3 plugin/
│  │           ├─ 2.4*  *.vim        # .vim files are loaded first under plugin
│  │           └─ 2.5*  *.lua        # .lua files are loaded afterwards and can overwrite .vim
│  └─ opt/                           # load later via :packadd <plugin> (manual/scripted loading)
│
├─ 3.0 plugin/                       # auto sourced at startup (after pack/*/start/*)
│   ├─ 3.1*  *.vim                   # first .vim files
│   └─ 3.2*  *.lua                   # then .lua files
│
├─ 4.0 after/                        # auto sourced AFTER all plugin/ above, your overrides
│   ├─ 4.1 plugin/                   # plugin overrides
│   │   ├─ 4.2*  *.vim               # first .vim files
│   │   └─ 4.3*  *.lua               # then .lua files
│   │
│   ├─ 6.* ftplugin/*.vim            # overrides
│   ├─ 6.* indent/<ft>.lua           # overrides
│   ├─ 6.* syntax/<ft>.vim           # overrides
│   ├─ 6.* queries/<ft>/*.scm        # overrides
│   └─ 6.* colors/*.lua              # overrides
│
├─ 5.0 ftdetect/*.vim                # filetype detection on buffer/file load (:help ftdetect)
├─ 5.* ftplugin/<ft>.lua             # per filetype general settings (:help ftplugin)
├─ 5.* indent/<ft>.lua               # per filetype indent settings (:help indent-expression)
├─ 5.* syntax/<ft>.vim               # per filetype syntax settings (:help syntax)
├─ 5.* queries/<ft>/*.scm            # per filetype treesitter queries (:help treesitter-query)
├─ 5.* colors/*.lua                  # color scheme files (:help colorscheme)
│
├─ doc/*.txt                         # personal documentation (:help helptags)
├─ spell/en.utf-8.{add,add.spl}      # personal spelling files (:help spell)
├─ undo/                             # personal undo history (:help undodir) state_home
├─ autoload/<a>/<b>.vim              # function calls via a#b#funcinb() (:help autoload)
├─ compiler/{name}.{vim,lua}         # (:help compiler) TODO: make all this syntax
├─ keymap/                           # literal keyboard mappings (:help mbyte-keymap)
│   ├─ {keymap}_utf-8.vim
│   └─ {keymap}.vim
├─ rplugin/                          # glorious/disgusting remote plugins *spit* (:help remote-plugin)
├─ lang/*/                           # verbal language (:help language)
├─ lsp/<config>.lua                  # yeh boi (:help lsp)
├─ parser/{lang}.*                   # treesitter library search path (:help treesitter-parsers)
├─ menu.vim                          # glorious/disgusting mouse menus (:help menus)
├─ tutor/                            # Sanctimonious tutor creation (:help Tutor)
├─ ???/                              # TODO: Am I missing anything here? (:help usr)
```

Work on removing everything in pack (I don't want a package manager, I should make all of the things myself, how hard could it be?) Practice structure to have, what am I missing?

What I'm aiming to do writing everything myself:

```
0.0 ~/.config/nvim/                 # (%LOCALAPPDATA%\nvim on Windows)
│
├─ 1.* lua/                         # init.lua modules you `require(...)` (:help lua-module-load)
│   ├─ home/{set,keys,cmd,...}.lua  # home default setup, easy to comment in/out in init.lua
│   └─ work/{set,keys,cmd,...}.lua  # work default setup, easy to comment in/out in init.lua
│
│ TODO: Turn these into my own minimal plugins
├─ 1.* lua/                         # only when you `require(...)` default setup
│   ├─ set/                         # sets
│   ├─ keys/                        # keymaps
│   ├─ cmd/                         # autocmds & augroups
│   ├─ autopairs/                   # autopairs (I can get minimal with this for sure)
│   ├─ barbar/                      # tabs and buffer/file views (maybe separate tabs and buffers, but maybe also put them together?)
│   ├─ terminal/                    # terminal stuff in neovim?
│   ├─ blink/                       # completions (maybe can be paired with autopairs, do I need a lot of this?)
│   ├─ colorizer/                   # viewing colors in neovim (another parser? how would this work?)
│   ├─ dashboard/                   # startup screen for nvim (when no file is loaded, keyboard shortcuts or do I need this at all?)
│   ├─ gitsigns/                    # git buffer integration (git integration in general)
│   ├─ indent-blankline/            # visualizing indentations/scope (probably can be easily done through text alone)
│   ├─ lualine/                     # status line (try looking at other peoples for inspiration, also just basic text, no icons)
│   ├─ markdown-preview/            # markdown previews (javascript? barf...)
│   ├─ nvim-dap/ nvim-dap-ui/       # debugger integration? (Maybe try rad debugger)
│   ├─ nvim-tree/                   # file explorer (netrw? or something else...? terminal maybe?)
│   ├─ telescope/ telescope-ui-select/ telescope.keys.lua telescope-fzf-native/        # fuzzy finder over lists (rg and fd? could be minimal)
│   ├─ todo-comments/               # visualizing todo comments (parser of text for certain syntax in a comment)
│   ├─ tokyonight/                  # colorscheme creation time! (I really like onedark, maybe use as inspiration)
│   ├─ treesitter/                  # syntax highlighting (builtin neovim woohoo)
│   ├─ undotree/                    # undo history visualizer (do I need this? Can I make something minimal? probably)
│   ├─ which-key/                   # keymaps memory (do I need this either? Can I make something minimal? basically this is a cheat sheet right? parse neovim for writing to a text file maybe and check for discrepencies when they occur at a syntactical level? Is that possible?)
│   ├─ nvim-web-devicons/           # Provides nerd fonts for Neovim plugins (is this needed? What if I install a nerd font using pacman or something, can't I just use the ones I have then without this plugin?)
│   ├─ friendly-snippets/           # snippets collection for different programming languages (probably will need to make my own snippets. That way they can be useful to me?)
│   ├─ fidget/                      # notification ui and progress messages (includes lsp integration, but maybe this could be an overlay status thingy in general that interfaces with nvim completely?)
│   ├─ nvim-nio/                    # asynchronous IO (wtf is this?)
│   ├─ plenary/                     # a bunch of lua functions (might need to look at these in depth to determine what these were, and if I can see myself using any of them too)
│   ├─ lspconfig/ lsp.servers.lua mason/ mason-lspconfig/ lsp.cmd.lua mason-nvim-dap/ lsp.keys.lua   # collection of lsp server configurations for the nvim lsp client (I could also just configure it myself for the ones I actually use. I should make a list of ones I actually use)
│   └─ mini/                        # mini.ai (only one I use. It allows inside and around vim functionality for acting on text. This could be pretty easy to do as well and also very scriptable)
│
│ TODO: Whatever auto loaded plugins I want go here (work/home)
├─ 2.0 plugin/                      # auto sourced at startup after 1.*
│   └─ 2.1*  *.lua                  # .lua files
│
├─ 3.0 after/                       # 3.0 sourced AFTER all 1.*-2.*, your nvim overrides
│   ├─ 3.1 plugin/                  # plugin overrides
│   │   └─ 3.2*  *.lua              # .lua files
│   │
│   ├─ 5.* ftplugin/*.vim           # per filetype buffer/file load overrides
│   ├─ 5.* indent/<ft>.lua          # per filetype buffer/file load overrides
│   ├─ 5.* syntax/<ft>.vim          # per filetype buffer/file load overrides
│   ├─ 5.* queries/<ft>/*.scm       # per filetype buffer/file load overrides
│   └─ 5.* colors/*.lua             # per filetype buffer/file load overrides
│
├─ 4.0 ftdetect/*.vim               # filetype detection on buffer/file load (:help ftdetect)
├─ 4.* ftplugin/<ft>.lua            # per filetype general settings (:help ftplugin)
├─ 4.* indent/<ft>.lua              # per filetype indent settings (:help indent-expression)
├─ 4.* syntax/<ft>.vim              # per filetype syntax settings (:help syntax)
├─ 4.* queries/<ft>/*.scm           # per filetype treesitter queries (:help treesitter-query)
├─ 4.* colors/*.lua                 # color scheme files (:help colorscheme)
│
├─ doc/*.txt                        # personal documentation (:help helptags)
│
├─ spell/en.utf-8.{add,add.spl}     # personal spelling files (:help spell)
│
├─ compiler/{name}.{vim,lua}        # (:help compiler)
│
├─ lsp/<config>.lua                 # yeh boi (:help lsp)
│
├─ parser/{lang}.*                  # treesitter library search path (:help treesitter-parsers)
│
├─ menu.vim                         # glorious/disgusting mouse menus (:help menus) - on the fence for this one
│
├─ tutor/                           # Sanctimonious tutor creation (:help Tutor)
│
├─ ~/.local/state/nvim/undodir/*    # personal undo history (:help undodir) state_home
│
└─ ???/                             # TODO: Am I missing anything here? (:help usr)

```
