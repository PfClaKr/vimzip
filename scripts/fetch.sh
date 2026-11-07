#!/bin/sh
# Download static ctags, fzf, shellcheck, ripgrep into $1/bin.
set -eu
cd "$(dirname "$0")/.."
. ./versions.env
OUT=$(mkdir -p "$1/bin" && cd "$1" && pwd)
W=$(mktemp -d)
trap 'rm -rf "$W"' EXIT
gh=https://github.com
get() { mkdir -p "$W/$1"; curl -fsSL "$2" | tar -x${3}f - -C "$W/$1"; }

d=${CTAGS_VERSION%%+*}
get ctags "$gh/universal-ctags/ctags-nightly-build/releases/download/$(echo "$CTAGS_VERSION" | sed 's/+/%2B/')/uctags-$d-linux-x86_64.release.tar.xz" J
get fzf "$gh/junegunn/fzf/releases/download/$FZF_VERSION/fzf-${FZF_VERSION#v}-linux_amd64.tar.gz" z
get sc "$gh/koalaman/shellcheck/releases/download/$SHELLCHECK_VERSION/shellcheck-$SHELLCHECK_VERSION.linux.x86_64.tar.xz" J
get rg "$gh/BurntSushi/ripgrep/releases/download/$RG_VERSION/ripgrep-$RG_VERSION-x86_64-unknown-linux-musl.tar.gz" z

cp "$W"/ctags/*/bin/ctags "$W"/ctags/*/bin/readtags "$W/fzf/fzf" "$W"/sc/*/shellcheck "$W"/rg/*/rg "$OUT/bin/"

# fzf vim plugin, matching the binary version
mkdir -p "$OUT/pack/vimzip/start/fzf/plugin"
curl -fsSL "https://raw.githubusercontent.com/junegunn/fzf/$FZF_VERSION/plugin/fzf.vim" -o "$OUT/pack/vimzip/start/fzf/plugin/fzf.vim"
