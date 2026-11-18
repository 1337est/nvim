#!/usr/bin/env bash
set -euo pipefail

# Load directory configuration
source "$(dirname -- "${BASH_SOURCE[0]}")/install-dirs.sh"

rustup_version=1.29.0
rustup_url="https://sh.rustup.rs"
rustup_home="$HOME/.rustup"
cargo_home="$HOME/.cargo"
rustup_root="$cargo_home/bin/rustup"
cargo_root="$cargo_home/bin/cargo"
rust_version=1.97.1

bat_version=0.26.1
bat_package="bat"
bat_binary="bat"

fd_version=10.4.2
fd_package="fd-find"
fd_binary="fd"

lsd_version=1.2.0
lsd_package="lsd"
lsd_binary="lsd"

rg_version=15.2.0
rg_package="ripgrep"
rg_binary="rg"

tldr_version=1.8.1
tldr_package="tealdeer"
tldr_binary="tldr"

tree_sitter_version=0.26.11
tree_sitter_package="tree-sitter-cli"
tree_sitter_binary="tree-sitter"

profile="$HOME/.profile"

export RUSTUP_HOME="$rustup_home"
export CARGO_HOME="$cargo_home"
export PATH="$cargo_home/bin:$PATH"

rust_install() {
    if [ ! -x "$rustup_root" ]; then
        curl --proto '=https' --tlsv1.2 -sSf "$rustup_url" |
            RUSTUP_VERSION="$rustup_version" sh -s -- \
                -y \
                --profile minimal \
                --default-toolchain none \
                --no-modify-path
    fi

    if [[ "$("$rustup_root" --version)" != "rustup $rustup_version "* ]]; then
        RUSTUP_VERSION="$rustup_version" "$rustup_root" self update
    fi

    "$rustup_root" set auto-self-update disable
    "$rustup_root" toolchain install "$rust_version" \
        --profile minimal \
        --component rust-analyzer \
        --no-self-update
    "$rustup_root" default "$rust_version"

    [[ "$("$cargo_home/bin/rustc" --version)" == "rustc $rust_version "* ]] || {
        echo "Rust $rust_version verification failed." >&2
        return 1
    }
    [[ "$("$cargo_root" --version)" == "cargo $rust_version "* ]] || {
        echo "Cargo $rust_version verification failed." >&2
        return 1
    }
}

dotprofile() {
    touch "$profile"

    if ! grep -Fq "export RUSTUP_HOME=\"$rustup_home\"" "$profile" &&
       ! grep -Fq 'export RUSTUP_HOME="$HOME/.rustup"' "$profile"; then
        cat >> "$profile" <<EOF

# Rust toolchain
export RUSTUP_HOME="$rustup_home"
export CARGO_HOME="$cargo_home"
if [ -d "\$CARGO_HOME/bin" ]; then
    PATH="\$CARGO_HOME/bin:\$PATH"
fi
EOF
    fi
}

cargo_modules() {
    "$cargo_root" +"$rust_version" install --locked --version "$bat_version" "$bat_package"
    "$cargo_root" +"$rust_version" install --locked --version "$fd_version" "$fd_package"
    "$cargo_root" +"$rust_version" install --locked --version "$lsd_version" "$lsd_package"
    "$cargo_root" +"$rust_version" install --locked --version "$rg_version" "$rg_package"
    "$cargo_root" +"$rust_version" install --locked --version "$tldr_version" "$tldr_package"
    "$cargo_root" +"$rust_version" install --locked --version "$tree_sitter_version" "$tree_sitter_package"
}

rust_install
dotprofile
cargo_modules
