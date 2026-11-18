#!/usr/bin/env bash
set -euo pipefail

# Usage
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <0.16.0|0.17.0|0.18.0-dev>" >&2
    exit 1
fi

# Input
requested="$1"
case "$requested" in
    0.16.0)
        llvm_series=21.x
        revision=0.16.0
        directory=0.16.0
        ;;
    0.17.0)
        llvm_series=22.x
        revision=0.17.0
        directory=0.17.0
        ;;
    0.18.0-dev)
        llvm_series=23.x
        revision=master
        directory=master
        ;;
    *)
        echo "Usage: $0 <0.16.0|0.17.0|0.18.0-dev>" >&2
        exit 1
        ;;
esac

# Load directory configuration
source "$(dirname -- "${BASH_SOURCE[0]}")/install-dirs.sh"

# Directories
llvm_upstream="https://github.com/llvm/llvm-project.git"
llvm_source="$src_dir/llvm-project"
llvm_cache="$src_cache/llvm-project/$llvm_series"
llvm_build="$llvm_cache/build"
llvm_ccache="$llvm_cache/ccache"
llvm_prefix="$src_prefix/llvm-project/$llvm_series"
llvm_enable_projects="lld;clang"

zig_upstream="https://codeberg.org/ziglang/zig.git"
zig_source="$src_dir/zig"
zig_cache="$src_cache/zig/$directory"
zig_build="$zig_cache/build"
zig_ccache="$zig_cache/ccache"
zig_global_cache="$zig_cache/global"
zig_local_cache="$zig_cache/local"
zig_local_pkg="$zig_cache/pkg"
zig_prefix="$src_prefix/zig/$directory"

zls_upstream="https://github.com/zigtools/zls.git"
zls_source="$src_dir/zls"
zls_cache="$src_cache/zls/$directory"
zls_build="$zls_cache/build"
zls_global_cache="$zls_cache/global"
zls_pkg="$zls_cache/pkg"
zls_prefix="$src_prefix/zls/$directory"

# Sets jobs to half of what is available, so 12 cores would use 6 for jobs
jobs=$(( $(nproc) / 2 ))
[ "$jobs" -ge 1 ] || jobs=1

llvm() {
    if [ "$directory" != master ] &&
       [ -x "$llvm_prefix/bin/llvm-config" ] &&
       [ -x "$llvm_prefix/bin/clang" ] &&
       [ -x "$llvm_prefix/bin/ld.lld" ] &&
       [[ "$("$llvm_prefix/bin/llvm-config" --version 2>/dev/null)" == "${llvm_series%%.*}".* ]]; then
        echo "LLVM $llvm_series already installed."
        return
    fi

    if [ ! -d "$llvm_source/.git" ]; then
        git clone "$llvm_upstream" "$llvm_source"
    fi

    [ -z "$(git -C "$llvm_source" status --porcelain)" ] || {
        echo "Uncommitted changes in $llvm_source" >&2
        return 1
    }

    git -C "$llvm_source" checkout "release/$llvm_series"

    if [ "$directory" = master ]; then
        git -C "$llvm_source" pull --ff-only origin "release/$llvm_series"
    fi

    mkdir -p "$llvm_build" "$llvm_ccache" "$llvm_prefix"

    cmake \
        -S "$llvm_source/llvm" \
        -B "$llvm_build" \
        -G Ninja \
        -DCMAKE_INSTALL_PREFIX="$llvm_prefix" \
        -DCMAKE_BUILD_TYPE=Release \
        -DLLVM_ENABLE_PROJECTS="$llvm_enable_projects" \
        -DLLVM_ENABLE_LIBXML2=OFF \
        -DLLVM_ENABLE_TERMINFO=OFF \
        -DLLVM_ENABLE_LIBEDIT=OFF \
        -DLLVM_ENABLE_ASSERTIONS=ON \
        -DLLVM_ENABLE_ZSTD=OFF \
        -DLLVM_PARALLEL_LINK_JOBS=1 \
        -DLLVM_CCACHE_BUILD=ON \
        -DLLVM_CCACHE_DIR="$llvm_ccache"

    ninja -C "$llvm_build" -j"$jobs" install

    "$llvm_prefix/bin/llvm-config" --version
}

zig() {
    if [ "$directory" != master ] &&
       [ -x "$zig_prefix/bin/zig" ] &&
       [ -d "$zig_prefix/lib/zig/std" ]; then
        local installed
        installed="$("$zig_prefix/bin/zig" version 2>/dev/null)" || installed=''

        if [ "$installed" = "$requested" ]; then
            echo "Zig $installed already installed."
            return
        fi
    fi

    if [ ! -d "$zig_source/.git" ]; then
        git clone "$zig_upstream" "$zig_source"
    fi

    [ -z "$(git -C "$zig_source" status --porcelain)" ] || {
        echo "Uncommitted changes in $zig_source" >&2
        return 1
    }

    git -C "$zig_source" checkout "$revision"

    if [ "$directory" = master ]; then
        git -C "$zig_source" pull --ff-only origin master
    fi

    mkdir -p \
        "$zig_build" \
        "$zig_ccache" \
        "$zig_local_cache" \
        "$zig_global_cache" \
        "$zig_prefix"

    if [ "$directory" != 0.16.0 ]; then
        mkdir -p "$zig_local_pkg"
    fi

    CCACHE_DIR="$zig_ccache" \
    cmake \
        -S "$zig_source" \
        -B "$zig_build" \
        -G Ninja \
        -DCMAKE_INSTALL_PREFIX="$zig_prefix" \
        -DCMAKE_PREFIX_PATH="$llvm_prefix" \
        -DCMAKE_BUILD_TYPE=Release \
        -DZIG_USE_LLVM_CONFIG=ON \
        -DZIG_STATIC_LLVM=ON \
        -DZIG_NO_LIB=OFF \
        -DCMAKE_C_COMPILER_LAUNCHER=ccache \
        -DCMAKE_CXX_COMPILER_LAUNCHER=ccache \
        -DZIG_EXTRA_BUILD_ARGS=-j4

    if [ "$directory" = 0.16.0 ]; then
        CCACHE_DIR="$zig_ccache" \
        ZIG_LOCAL_CACHE_DIR="$zig_local_cache" \
        ZIG_GLOBAL_CACHE_DIR="$zig_global_cache" \
        ninja -C "$zig_build" -j"$jobs" install
    else
        CCACHE_DIR="$zig_ccache" \
        ZIG_LOCAL_CACHE_DIR="$zig_local_cache" \
        ZIG_GLOBAL_CACHE_DIR="$zig_global_cache" \
        ZIG_LOCAL_PKG_DIR="$zig_local_pkg" \
        ninja -C "$zig_build" -j"$jobs" install
    fi

    "$zig_prefix/bin/zig" version
}

zls() {
    if [ "$directory" != master ] &&
       [ -x "$zls_prefix/bin/zls" ]; then
        local installed
        installed="$("$zls_prefix/bin/zls" version 2>/dev/null)" || installed=''

        if [ "$installed" = "$requested" ]; then
            echo "ZLS $installed already installed."
            return
        fi
    fi

    if [ ! -d "$zls_source/.git" ]; then
        git clone "$zls_upstream" "$zls_source"
    fi

    [ -z "$(git -C "$zls_source" status --porcelain)" ] || {
        echo "Uncommitted changes in $zls_source" >&2
        return 1
    }

    git -C "$zls_source" checkout "$revision"

    if [ "$directory" = master ]; then
        git -C "$zls_source" pull --ff-only origin master
    fi

    mkdir -p "$zls_build" "$zls_global_cache" "$zls_prefix"

    if [ "$directory" = 0.16.0 ]; then
        (
            cd "$zls_source"

            "$zig_prefix/bin/zig" build \
                -Doptimize=ReleaseSafe \
                -j4 \
                --cache-dir "$zls_build" \
                --global-cache-dir "$zls_global_cache" \
                --prefix "$zls_prefix"
        )
    else
        mkdir -p "$zls_pkg"

        (
            cd "$zls_source"

            ZIG_GLOBAL_CACHE_DIR="$zls_global_cache" \
            ZIG_LOCAL_PKG_DIR="$zls_pkg" \
            "$zig_prefix/bin/zig" build \
                -Doptimize=safe \
                -j4 \
                --cache-dir "$zls_build" \
                --prefix "$zls_prefix"
        )
    fi

    "$zls_prefix/bin/zls" version
}

llvm
zig
zls
zig_links "$directory"
