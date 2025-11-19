# Quick todo

- [ ] Implement a basic/custom vim.snippet via the builtin vim lua module vim.snippet
-- [ ] Work the basic implementation with potential language servers: clangd, lua_ls, zig, etc...

# Telescope Builtin Functions I want to replace

As far as telescope relying on plenary. Some of the notable files may be: `rg plenary`

- Note: Below the only things that are kept are the files and the modules that mention plenary

## telescope.nvim-scm-1.rockspec

```
20:  'plenary.nvim',
```

### Notes


## doc\telescope_changelog.txt

```
95:Extension developers need to move to plenary.path, because we will remove the
98:Guide to switch over to plenary.path
101:        now:    require("plenary.path").path.sep
104:        now:    require("plenary.path").path.home
107:        now:    require("plenary.path"):new(filepath):make_relative(cwd)
110:        now:    require("plenary.path"):new(filepath):shorten()
114:        now:    require("plenary.path"):new(filepath):normalize(cwd)
117:        now:    require("plenary.path"):new(filepath):read()
120:        now:    require("plenary.path"):new(filepath):read(callback)
276:We finally removed usage of `plenary.filetype` to determine filetypes for
278:issues you no longer have to configure `plenary`, but rather read
```

### Notes


## doc\telescope.txt

```
547:                                    local path = require("plenary.path"):new(filepath)
2626:    compatibility with `plenary.path` and also avoids mangling valid Unix paths
```

### Notes


## lua\telescope\_.lua

```
3:local Object = require "plenary.class"
4:local log = require "plenary.log"
6:local async = require "plenary.async"
7:local channel = require("plenary.async").control.channel
```

### Notes


## lua\telescope\actions\history.lua

```
2:local Path = require "plenary.path"
29:-- TODO(conni2461): currently not present in plenary path only sync.
```

### Notes


## lua\telescope\config.lua

```
1:local strings = require "plenary.strings"
3:local os_sep = require("plenary.path").path.sep
668:                                local path = require("plenary.path"):new(filepath)
```

### Notes


## lua\telescope\actions\utils.lua

```
110:  local Path = require "plenary.path"
```

### Notes


## README.md

```
52:- [nvim-lua/plenary.nvim](https://github.com/nvim-lua/plenary.nvim) is required.
86:Plug 'nvim-lua/plenary.nvim'
94:call dein#add('nvim-lua/plenary.nvim')
105:  requires = { {'nvim-lua/plenary.nvim'} }
116:      dependencies = { 'nvim-lua/plenary.nvim' }
123:      dependencies = { 'nvim-lua/plenary.nvim' }
```

### Notes


## scripts\minimal_init.vim

```
2:set rtp+=../plenary.nvim/
5:runtime! plugin/plenary.vim
```

### Notes


## lua\tests\automated\utils_spec.lua

```
1:local Path = require "plenary.path"
```

### Notes


## lua\telescope\actions\init.lua

```
60:local popup = require "plenary.popup"
```

### Notes


## lua\telescope\actions\set.lua

```
17:local Path = require "plenary.path"
```

### Notes


## lua\telescope\utils.lua

```
10:local Path = require "plenary.path"
11:local Job = require "plenary.job"
15:local truncate = require("plenary.strings").truncate
52:--- compatibility with `plenary.path` and also avoids mangling valid Unix paths
544:  local sourced_file = require("plenary.debug_utils").sourced_filepath()
```

### Notes


## lua\telescope\builtin\__lsp.lua

```
6:local channel = require("plenary.async.control").channel
```

### Notes


## lua\telescope\builtin\__git.lua

```
12:local strings = require "plenary.strings"
13:local Path = require "plenary.path"
```

### Notes


## lua\telescope\make_entry.lua

```
41:local strings = require "plenary.strings"
42:local Path = require "plenary.path"
```

### Notes


## lua\telescope\finders.lua

```
1:local Job = require "plenary.job"
31:For more information about how Jobs are implemented, checkout 'plenary.job'
```

### Notes


## lua\telescope\finders\async_static_finder.lua

```
1:local scheduler = require("plenary.async").util.scheduler
```

### Notes


## lua\telescope\algos\fzy.lua

```
10:local has_path, Path = pcall(require, "plenary.path")
```

### Notes


## lua\telescope\health.lua

```
32:  { lib = "plenary", optional = false },
```

### Notes


## lua\telescope\log.lua

```
1:return require("plenary.log").new {
```

### Notes


## lua\tests\automated\telescope_spec.lua

```
2:local Path = require "plenary.path"
```

### Notes


## lua\telescope\builtin\__files.lua

```
15:local Path = require "plenary.path"
```

### Notes


## lua\telescope\finders\async_oneshot_finder.lua

```
1:local async = require "plenary.async"
```

### Notes


## lua\telescope\builtin\__internal.lua

```
8:local Path = require "plenary.path"
240:    local sourced_file = require("plenary.debug_utils").sourced_filepath()
912:                    require("plenary.reload").reload_module(selection.value)
```

### Notes


## lua\telescope\testharness\init.lua

```
3:local Path = require "plenary.path"
```

### Notes


## lua\telescope\previewers\utils.lua

```
4:local strings = require "plenary.strings"
7:local Job = require "plenary.job"
8:local Path = require "plenary.path"
```

### Notes


## lua\telescope\previewers\buffer_previewer.lua

```
4:local Path = require "plenary.path"
20:-- TODO(fdschmidt93) switch to Job once file_maker callbacks get cleaned up with plenary async
150:  require("plenary.scandir").ls_async(filepath, {
```

### Notes


## lua\telescope\previewers\term_previewer.lua

```
5:local Path = require "plenary.path"
```

### Notes


## lua\telescope\pickers\entry_display.lua

```
61:local strings = require "plenary.strings"
```

### Notes


## lua\telescope\pickers.lua

```
5:local async = require "plenary.async"
7:local channel = require("plenary.async.control").channel
8:local popup = require "plenary.popup"
27:local truncate = require("plenary.strings").truncate
28:local strdisplaywidth = require("plenary.strings").strdisplaywidth
```

### Notes

## Telescope functionality that I want replaced at a macro level

1. buffers -> ls/buffers list
2. :help cmdline.txt -> :history -> history of previous commands
3. :help :messages -> messages and errors that Vim produces
4. :help man.lua -> man pages
5. List commands telescope.builtin.commands
6. telescope.builtin.current_buffer_fuzzy_find
7. telescope.builtin.current_buffer_tags (create one with ctags -R)
8. telescope.builtin.diagnostics
9. telescope.builtin.fd -> find_files
10. telescope.builtin.filetypes -> search and find filetypes (selects current buffer to found type)
11. telescope.builtin.git_commits -> gitdiff commits for the per commit
11. telescope.builtin.git_bcommits -> gitdiff commits for the current buffers per commit
12. telescope.builtin.git_branches -> searches git branches
13. telescope.builtin.status -> per file git status
14. telescope.builtin.help_tags -> lists nvim help_tags and opens them
15. telescope.builtin.jumplist -> get the jumplist and move to one of the jumps
16. telescope.builtin.highlights
17. telescope.builtin.keymaps
18. telescope.builtin.live_grep
19. telescope.builtin.loclist
20. telescope.builtin.lsp_definitions
21. telescope.builtin.lsp_document_symbols
22. telescope.builtin.lsp_dynamic_workspace_symbols
23. telescope.builtin.lsp_implementations
24. telescope.builtin.lsp_incoming_calls
24. telescope.builtin.lsp_outgoing_calls
24. telescope.builtin.lsp_references
24. telescope.builtin.lsp_type_definitions
24. telescope.builtin.lsp_workspace_symbols
26. telescope.builtin.marks
27. telescope.builtin.oldfiles
28. telescope.builtin.quickfix
29. telescope.builtin.quickfixhistory
30. telescope.builtin.registers
31. telescope.builtin.symbols (what is this?)
32. telescope.builtin.tags
33. telescope.builtin.tagstack
34. telescope.builtin.vim_options
35. telescope.builtin.treesitter
