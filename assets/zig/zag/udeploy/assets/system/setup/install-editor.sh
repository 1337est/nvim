#!/usr/bin/env bash
set -euo pipefail

# Load directory configuration
source "$(dirname -- "${BASH_SOURCE[0]}")/install-dirs.sh"

# JetBrainsMono Nerd Font
font_version=3.5.1
font_url="https://github.com/ryanoasis/nerd-fonts/releases/download/v${font_version}/JetBrainsMono.tar.xz"
font_checksum="04d5e8f903693f9dd13e16f867e994834e681eb3c72c0d337a770dcda09010cf"
font_cache="$src_cache/nerd-fonts/$font_version"
font_archive="$font_cache/JetBrainsMono.tar.xz"
font_prefix="$font_dir/JetBrainsMonoNerdFont/$font_version"

# Lua Language Server
luals_version=3.18.2
luals_upstream="https://github.com/LuaLS/lua-language-server.git"
luals_source="$src_dir/lua-language-server"
luals_build="$src_cache/lua-language-server/$luals_version/build"
luals_prefix="$src_prefix/lua-language-server/$luals_version"
luals_root="$luals_prefix/bin/lua-language-server"

# Neovim
nvim_version=0.12.6
nvim_upstream="https://github.com/neovim/neovim.git"
nvim_config_upstream="https://github.com/1337est/nvim.git"
nvim_source="$src_dir/neovim"
nvim_cache="$src_cache/neovim/$nvim_version"
nvim_deps="$nvim_cache/deps"
nvim_build="$nvim_cache/build"
nvim_ccache="$nvim_cache/ccache"
nvim_prefix="$src_prefix/neovim/$nvim_version"
nvim_root="$nvim_prefix/bin/nvim"
nvim_config="$HOME/.config/nvim"

jobs=$(( $(nproc) / 2 ))
[ "$jobs" -ge 1 ] || jobs=1

font_install() {
    if [ -f "$font_prefix/JetBrainsMonoNerdFont-Regular.ttf" ]; then
        echo "JetBrainsMono Nerd Font $font_version already installed."
        return
    fi

    mkdir -p "$font_cache" "$(dirname -- "$font_prefix")"

    if ! printf '%s  %s\n' "$font_checksum" "$font_archive" | sha256sum -c - >/dev/null 2>&1; then
        curl --proto '=https' --tlsv1.2 -fL "$font_url" -o "$font_archive.part"
        mv -- "$font_archive.part" "$font_archive"
    fi
    printf '%s  %s\n' "$font_checksum" "$font_archive" | sha256sum -c -

    [ ! -e "$font_prefix" ] && [ ! -L "$font_prefix" ] || {
        echo "Incomplete font installation: $font_prefix" >&2
        return 1
    }

    local stage
    stage="$(mktemp -d "$(dirname -- "$font_prefix")/.JetBrainsMono.XXXXXX")"
    if ! tar -xJf "$font_archive" -C "$stage" ||
       [ ! -f "$stage/JetBrainsMonoNerdFont-Regular.ttf" ]; then
        rm -rf -- "$stage"
        echo 'JetBrainsMono extraction failed.' >&2
        return 1
    fi

    mv -- "$stage" "$font_prefix"
    if command -v fc-cache >/dev/null 2>&1; then fc-cache -f "$font_prefix"; fi
}

luals_install() {
    if [ -x "$luals_root" ] &&
       [ -f "$luals_prefix/changelog.md" ] &&
       [ "$("$luals_root" --version 2>/dev/null)" = "$luals_version" ]; then
        echo "LuaLS $luals_version already installed."
        return
    fi

    if [ ! -d "$luals_source/.git" ]; then
        git clone "$luals_upstream" "$luals_source"
    fi
    [ -z "$(git -C "$luals_source" status --porcelain)" ] || {
        echo "Uncommitted changes in $luals_source" >&2
        return 1
    }

    git -C "$luals_source" fetch --tags origin
    git -C "$luals_source" checkout --detach "$luals_version"

    mkdir -p "$luals_build" "$luals_prefix"
    cp -a "$luals_source/." "$luals_build/"

    (
        cd "$luals_build"
        ./make.sh
        [ -x bin/lua-language-server ] && [ -f bin/main.lua ]
        cp -a bin main.lua debugger.lua changelog.md script locale meta "$luals_prefix/"
    )

    [ "$("$luals_root" --version)" = "$luals_version" ] || {
        echo "LuaLS $luals_version verification failed." >&2
        return 1
    }
}

nvim_install() {
    if [ ! -e "$nvim_config" ] && [ ! -L "$nvim_config" ]; then
        mkdir -p "$(dirname -- "$nvim_config")"
        git clone "$nvim_config_upstream" "$nvim_config"
    fi

    if [ -x "$nvim_root" ] &&
       [ -d "$nvim_prefix/share/nvim/runtime" ] &&
       [ "$("$nvim_root" --version | sed -n '1p')" = "NVIM v$nvim_version" ]; then
        echo "Neovim $nvim_version already installed."
        return
    fi

    if [ ! -d "$nvim_source/.git" ]; then
        git clone "$nvim_upstream" "$nvim_source"
    fi
    [ -z "$(git -C "$nvim_source" status --porcelain)" ] || {
        echo "Uncommitted changes in $nvim_source" >&2
        return 1
    }

    git -C "$nvim_source" fetch --tags origin
    git -C "$nvim_source" checkout --detach "v$nvim_version"

    mkdir -p "$nvim_deps" "$nvim_build" "$nvim_ccache" "$nvim_prefix"

    CCACHE_DIR="$nvim_ccache" cmake \
        -S "$nvim_source/cmake.deps" \
        -B "$nvim_deps" \
        -G Ninja \
        -DCMAKE_BUILD_TYPE=Release

    CCACHE_DIR="$nvim_ccache" ninja -C "$nvim_deps" -j"$jobs"

    CCACHE_DIR="$nvim_ccache" cmake \
        -S "$nvim_source" \
        -B "$nvim_build" \
        -G Ninja \
        -DCMAKE_INSTALL_PREFIX="$nvim_prefix" \
        -DCMAKE_BUILD_TYPE=Release \
        -DDEPS_PREFIX="$nvim_deps/usr" \
        -DCMAKE_C_COMPILER_LAUNCHER=ccache

    CCACHE_DIR="$nvim_ccache" ninja -C "$nvim_build" -j"$jobs" install

    [ "$("$nvim_root" --version | sed -n '1p')" = "NVIM v$nvim_version" ] || {
        echo "Neovim $nvim_version verification failed." >&2
        return 1
    }
}

font_install
luals_install
nvim_install

# Executable symlinks
link_bin "$luals_root" lua-language-server
link_bin "$nvim_root" nvim
