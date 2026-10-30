#!/usr/bin/env bash
set -euo pipefail

# Remote project dl/source dir block with unique build cache and install prefixes
src_dir="$HOME/src"
src_cache="$HOME/.cache/src"
src_prefix="$HOME/.local/src"

# Personal project dir with unique build cache and install prefixes
mkit_dir="$HOME/mkit"
mkit_cache="$HOME/.cache/mkit"
mkit_prefix="$HOME/.local/mkit"

# Personal temporary/trash/download directory. Should be used over /tmp
tmp_dir="$HOME/tmp"

# Personal executable directories
bin_dir="$HOME/.local/bin"
script_dir="$HOME/.local/script"

# Personal fonts dir
font_dir="$HOME/.local/share/fonts"

# Bash completions dir
bash_completions_dir="$HOME/.local/share/bash-completion/completions"

mkdir -p \
    "$src_dir" "$src_cache" "$src_prefix" \
    "$mkit_dir" "$mkit_cache" "$mkit_prefix" \
    "$tmp_dir" \
    "$bin_dir" "$script_dir" \
    "$font_dir" \
    "$bash_completions_dir"

# Personal executable symlinks
link_bin() {
    local target="$1"
    local link="$bin_dir/$2"

    [ -x "$target" ] || {
        echo "Missing executable: $target" >&2
        return 1
    }

    if [ -e "$link" ] && [ ! -L "$link" ]; then
        echo "Refusing to overwrite: $link" >&2
        return 1
    fi

    ln -sfnT "$target" "$link"
}

# Current installation symlink
link_current() {
    local root="$1"
    local version="$2"
    local binary="$3"
    local current="$root/current"

    [ -x "$root/$version/bin/$binary" ] || return 0

    if [ ! -e "$current" ] && [ ! -L "$current" ]; then
        ln -s "$version" "$current"
    fi
}

# Zig, ZLS, and LLVM symlinks
zig_links() {
    local version="$1"

    # Version-specific executables
    link_bin "$src_prefix/zig/$version/bin/zig" "zig-$version"
    link_bin "$src_prefix/zls/$version/bin/zls" "zls-$version"

    # Default current versions
    link_current "$src_prefix/zig" 0.17.0 zig
    link_current "$src_prefix/zls" 0.17.0 zls
    link_current "$src_prefix/llvm-project" 22.x llvm-config

    # Executables referencing current
    if [ -x "$src_prefix/zig/current/bin/zig" ]; then
        link_bin "$src_prefix/zig/current/bin/zig" zig
    fi

    if [ -x "$src_prefix/zls/current/bin/zls" ]; then
        link_bin "$src_prefix/zls/current/bin/zls" zls
    fi
}
