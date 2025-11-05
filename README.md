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
└─ tutor/                            # Sanctimonious tutor creation (:help Tutor)

~/.local/state/nvim/
│
├─ viewdir/*
└─ undodir/*
```

Potential skeleton structure

```
~/.config/nvim/ # (%LOCALAPPDATA%\nvim on Windows)
│
├─ init.lua
│
├─ lua/
│   ├─ 1337est/*.lua
│   └─ work/*.lua
│
├─ plugin/*.lua
│
├─ after/
│   ├─ plugin/*.lua
│   ├─ ftplugin/*.vim
│   ├─ indent/<ft>.lua
│   ├─ syntax/<ft>.vim
│   ├─ queries/<ft>/*.scm
│   └─ colors/*.lua
│
├─ ftdetect/*.vim
├─ ftplugin/<ft>.lua
├─ indent/<ft>.lua
├─ syntax/<ft>.vim
├─ queries/<ft>/*.scm
├─ colors/*.lua
├─ doc/*.txt
├─ spell/en.utf-8.{add,add.spl}
├─ compiler/{name}.{vim,lua}
├─ lsp/<config>.lua
├─ parser/{lang}.*
├─ menu.vim
├─ tutor/

~/.local/state/nvim/
│
├─ viewdir/*
└─ undodir/*
```

Current working structure

```
~/.config/nvim/ # (%LOCALAPPDATA%\nvim on Windows)
│
└─ init.lua

~/.local/state/nvim/
│
├─ viewdir/*
└─ undodir/*
```
