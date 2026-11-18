tree before refactor. Currently projects are of the form:

```
<project>/README.md
<project>/build.zig
<project>/build.zig.zon
<project>/src/main.zig
```

This is the overall structure for the most part, but I have a lot of single file programs. I think those should be structured:

```
README.md       // might turn this into doc/<project>.md later
build.zig       // builds for all projects
build.zig.zon   // contains like a link to all build.zig.zon files? Not sure yet.
src/<project>.zig
src/<project>/*     // previous structure when necessary without the build.zig/build.zig.zon/README.md files
```

Then that's it. For now documentation should just live at the top of the file for now. These are just programs to help me or random development anyways. I should treat this like a giant monorepo of my personal projects that contain (in my opinion) small zig programs (nothing over 10k LOC). Anything over 10K LOC wouldn't be "big", but it wouldn't be "small" anymore I think.

Formulating layout:

```
README.md
build.zig
build.zig.zon

src/3dbg.zig    README.md, build.zig, build.zig.zon

src/clift.zig    README.md, build.zig, build.zig.zon

src/doop.zig    README.md

src/nostrum.zig    README.md, build.zig, build.zig.zon, main.zig, root.zig, sqlite.zig

src/rhei.zig    verify, add to mono repo

src/wagon.zig    README.md, build.zig, build.zig.zon, main.zig

src/template.zig    README.md, build.zig, build.zig.zon, main.zig
src/template/init/personal/*
src/template/init/work/*

src/udeploy.zig    README.md, build.zig, build.zig.zon, main.zig
src/udeploy/assets/*

src/view.zig    view.zig

src/zwe.zig    README.md, build.zig, build.zig.zon, main.zig
src/zwe/Config.zig
src/zwe/config.zon
src/zwe/editor/nvim/lsp/zls.lua
src/zwe/editor/nvim/lua/zwe.lua

lib/ramen.zig    README.md, build.zig, build.zig.zon, linux.zig
lib/ramen/broth.zig
lib/ramen/noodles.zig

lib/sockman.zig  // README.md, build.zig, build.zig.zon, main.zig, test.zig

lib/systemd.zig  // README.md, build.zig, build.zig.zon, main.zig
```
