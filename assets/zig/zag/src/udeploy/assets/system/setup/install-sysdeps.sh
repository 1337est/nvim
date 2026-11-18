#!/usr/bin/env bash
set -euo pipefail

# Basic developer tools/dependencies
sudo apt update
sudo apt install \
    vim \
    git \
    curl \
    apache2 \
    cmake \
    make \
    ninja-build \
    gcc \
    g++ \
    ccache \
    clangd \
    rsync \
    net-tools \
    btop \
    tree \
    gettext \
    unzip \
    zip \
    xz-utils \
    fontconfig
