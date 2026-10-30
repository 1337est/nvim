```
~/.config/nvim/assets/zig/zag/README.md (zag is no longer a library, but a host to all my personal zig projects so I don't have to hunt down all of my zig projects when there are breaking changes. Will likely keep it like this until version 1.0)
~/.config/nvim/assets/zig/zag/template/
~/.config/nvim/assets/zig/zag/zwe/
~/.config/nvim/assets/zig/zag/clift/
~/.config/nvim/assets/zig/zag/nostrum/
~/.config/nvim/assets/zig/zag/rhei/
~/.config/nvim/assets/zig/zag/udeploy/
~/.config/nvim/assets/zig/zag/wagon/
~/.config/nvim/assets/zig/zag/systemd/
~/.config/nvim/assets/zig/zag/sockman/
~/.config/nvim/assets/zig/zag/ramen/

pj1
~/.config/nvim/assets/zig/zag/template/README.md
~/.config/nvim/assets/zig/zag/template/build.zig (personal/, work/)
~/.config/nvim/assets/zig/zag/template/build.zig.zon
~/.config/nvim/assets/zig/zag/template/.gitignore
~/.config/nvim/assets/zig/zag/template/main.zig (sets up a template build. Still need to run `zig init -m` on new repo to create `build.zig.zon` file. Just copies contents of either personal or work to where you want it)
~/.config/nvim/assets/zig/zag/template/personal/build.zig (personal)
~/.config/nvim/assets/zig/zag/template/personal/.gitignore
~/.config/nvim/assets/zig/zag/template/personal/src/main.zig
~/.config/nvim/assets/zig/zag/template/work/build.zig (work.zig)
~/.config/nvim/assets/zig/zag/template/work/.gitignore
~/.config/nvim/assets/zig/zag/template/work/src/main.zig

pj2
~/.config/nvim/assets/zig/zag/zwe/README.md
~/.config/nvim/assets/zig/zag/zwe/build.zig
~/.config/nvim/assets/zig/zag/zwe/build.zig.zon
~/.config/nvim/assets/zig/zag/zwe/.gitignore
~/.config/nvim/assets/zig/zag/zwe/src/main.zig

pj3
~/.config/nvim/assets/zig/zag/clift/README.md
~/.config/nvim/assets/zig/zag/clift/build.zig
~/.config/nvim/assets/zig/zag/clift/build.zig.zon
~/.config/nvim/assets/zig/zag/clift/.gitignore
~/.config/nvim/assets/zig/zag/clift/src/main.zig

pj4
~/.config/nvim/assets/zig/zag/nostrum/README.md
~/.config/nvim/assets/zig/zag/nostrum/build.zig
~/.config/nvim/assets/zig/zag/nostrum/build.zig.zon
~/.config/nvim/assets/zig/zag/nostrum/.gitignore
~/.config/nvim/assets/zig/zag/nostrum/src/main.zig

pj5
~/.config/nvim/assets/zig/zag/rhei/README.md
~/.config/nvim/assets/zig/zag/rhei/build.zig
~/.config/nvim/assets/zig/zag/rhei/build.zig.zon
~/.config/nvim/assets/zig/zag/rhei/.gitignore
~/.config/nvim/assets/zig/zag/rhei/src/main.zig

pj6
~/.config/nvim/assets/zig/zag/udeploy/README.md
~/.config/nvim/assets/zig/zag/udeploy/build.zig
~/.config/nvim/assets/zig/zag/udeploy/build.zig.zon
~/.config/nvim/assets/zig/zag/udeploy/.gitignore
~/.config/nvim/assets/zig/zag/udeploy/src/main.zig
~/.config/nvim/assets/zig/zag/udeploy/assets/system/setup/install-dirs.sh
~/.config/nvim/assets/zig/zag/udeploy/assets/system/setup/install-editor.sh
~/.config/nvim/assets/zig/zag/udeploy/assets/system/setup/install-go.sh
~/.config/nvim/assets/zig/zag/udeploy/assets/system/setup/install-rust.sh
~/.config/nvim/assets/zig/zag/udeploy/assets/system/setup/install-sysdeps.sh
~/.config/nvim/assets/zig/zag/udeploy/assets/system/setup/install-zig.sh
~/.config/nvim/assets/zig/zag/udeploy/assets/system/copy/bash-completions/zig
~/.config/nvim/assets/zig/zag/udeploy/assets/system/copy/user-scripts/klemon.sh
~/.config/nvim/assets/zig/zag/udeploy/assets/system/copy/user-config/lemonade.toml

pj7
~/.config/nvim/assets/zig/zag/wagon/README.md
~/.config/nvim/assets/zig/zag/wagon/build.zig
~/.config/nvim/assets/zig/zag/wagon/build.zig.zon
~/.config/nvim/assets/zig/zag/wagon/.gitignore
~/.config/nvim/assets/zig/zag/wagon/src/main.zig

pj8
~/.config/nvim/assets/zig/zag/systemd/README.md
~/.config/nvim/assets/zig/zag/systemd/build.zig
~/.config/nvim/assets/zig/zag/systemd/build.zig.zon
~/.config/nvim/assets/zig/zag/systemd/.gitignore
~/.config/nvim/assets/zig/zag/systemd/src/main.zig

pj9
~/.config/nvim/assets/zig/zag/sockman/README.md
~/.config/nvim/assets/zig/zag/sockman/build.zig
~/.config/nvim/assets/zig/zag/sockman/build.zig.zon
~/.config/nvim/assets/zig/zag/sockman/.gitignore
~/.config/nvim/assets/zig/zag/sockman/src/main.zig

pj10
~/.config/nvim/assets/zig/zag/ramen/README.md
~/.config/nvim/assets/zig/zag/ramen/build.zig
~/.config/nvim/assets/zig/zag/ramen/build.zig.zon
~/.config/nvim/assets/zig/zag/ramen/.gitignore
~/.config/nvim/assets/zig/zag/ramen/linux.zig (combine into lib/ramen.zig)
~/.config/nvim/assets/zig/zag/ramen/lib/ramen.zig (previously zag.zig)

Then when this is done with this hierarchy/structure, I'll do `mv ~/.config/nvim/assets/zig/zag ~/mkit/`
```
