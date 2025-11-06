# neovim minimal config. TODO: plugins & TLDR

Lots of info on neovim structure moved to doc/1337tangyboi.txt

Potential skeleton structure (Keeping here as reference still)

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
├─ doc/1337tangyboi.txt
└─ init.lua

~/.local/state/nvim/
│
├─ log
├─ swap/*
├─ shada/*
├─ viewdir/*
└─ undodir/*
```
