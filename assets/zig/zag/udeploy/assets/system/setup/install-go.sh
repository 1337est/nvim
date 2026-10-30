#!/usr/bin/env bash
set -euo pipefail

# Load directory configuration
source "$(dirname -- "${BASH_SOURCE[0]}")/install-dirs.sh"

go_version=1.27.3
go_cache="$src_cache/go/$go_version"
go_prefix="$src_prefix/go/$go_version"
go_bin="$HOME/go/bin"
go_archive="$go_cache/go.tar.gz"
go_root="$go_prefix/bin/go"
[ "$(uname -s)" = Linux ] || { echo 'Linux is required.' >&2; exit 1; }
case "$(uname -m)" in
    x86_64)
        arch=amd64
        checksum=65efbc80fdc1fa2cd2631cad5b481777a68e8725f34e89f50fc6ac714e379b40
        ;;
    aarch64)
        arch=arm64
        checksum=a06e99309dbcbdca1a8ccd2282c3ee146e55930886e26b4f1193269587165f49
        ;;
    riscv64)
        arch=riscv64
        checksum=41fe171fb7fcf5574cba7d874c2732dca9161ce2dba631d754371951df9ea310
        ;;
    *)
        echo "Unsupported architecture: $(uname -m)" >&2
        exit 1
        ;;
esac
go_url="https://go.dev/dl/go${go_version}.linux-${arch}.tar.gz"

gopls_version="0.23.0"
gopls_url="golang.org/x/tools/gopls@v${gopls_version}"

fzf_version="0.74.5"
fzf_url="github.com/junegunn/fzf@v${fzf_version}"

duf_version="0.9.1"
duf_url="github.com/muesli/duf@v${duf_version}"

lemonade_version="1.1.1"
lemonade_url="github.com/lemonade-command/lemonade@v${lemonade_version}"

profile="$HOME/.profile"

go_install() {
    mkdir -p "$go_cache" "$src_prefix/go" "$go_bin"

    if [ -x "$go_root" ] && [[ "$("$go_root" version)" == "go version go$go_version "* ]]; then
        echo "Go $go_version already installed."
        return
    fi

    if ! printf '%s  %s\n' "$checksum" "$go_archive" | sha256sum -c - >/dev/null 2>&1; then
        curl --proto '=https' --tlsv1.2 -fL \
            "$go_url" \
            -o "$go_archive.part"
        mv -- "$go_archive.part" "$go_archive"
    fi

    printf '%s  %s\n' "$checksum" "$go_archive" | sha256sum -c -

    if [ -d "$go_prefix" ] && [ -z "$(ls -A -- "$go_prefix")" ]; then
        rmdir -- "$go_prefix"
    fi

    [ ! -e "$go_prefix" ] && [ ! -L "$go_prefix" ] || {
        echo "Existing incomplete installation: $go_prefix" >&2
        return 1
    }

    local stage
    stage="$(mktemp -d "$src_prefix/go/.go-$go_version.XXXXXX")"

    if ! tar -xzf "$go_archive" -C "$stage" --strip-components=1 ||
       ! [[ "$("$stage/bin/go" version)" == "go version go$go_version "* ]]; then
        rm -rf -- "$stage"
        echo 'Go extraction or version verification failed.' >&2
        return 1
    fi

    mv -- "$stage" "$go_prefix"
}

dotprofile() {
    touch "$profile"

    if ! grep -Fq "PATH=\"$go_prefix/bin:\$PATH\"" "$profile" &&
       ! grep -Fq "PATH=\"\$HOME/.local/src/go/$go_version/bin:\$PATH\"" "$profile"; then
        cat >> "$profile" <<EOF

# Go toolchain
if [ -d "$go_prefix/bin" ]; then
    PATH="$go_prefix/bin:\$PATH"
fi
EOF
    fi

    if ! grep -Fq "PATH=\"$go_bin:\$PATH\"" "$profile" &&
       ! grep -Fq 'PATH="$HOME/go/bin:$PATH"' "$profile"; then
        cat >> "$profile" <<EOF

# Go utilities
if [ -d "$go_bin" ]; then
    PATH="$go_bin:\$PATH"
fi
EOF
    fi
}

go_modules() {
    export GOBIN="$go_bin"

    [ -x "$go_bin/gopls" ] || "$go_root" install "$gopls_url"
    [ -x "$go_bin/fzf" ] || "$go_root" install "$fzf_url"
    [ -x "$go_bin/duf" ] || "$go_root" install "$duf_url"
    [ -x "$go_bin/lemonade" ] || "$go_root" install "$lemonade_url"
}

go_install
dotprofile
go_modules
