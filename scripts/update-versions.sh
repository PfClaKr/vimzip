#!/bin/sh
# Point versions.env at the latest upstream tags.
set -eu
cd "$(dirname "$0")/.."
latest() {
  v=$(git ls-remote --tags --refs "https://github.com/$1" | sed 's#.*refs/tags/##' | grep -E "$2" | sort -V | tail -n 1)
  [ -n "$v" ] || { echo "no tag: $1" >&2; exit 1; }
  echo "$v"
}
vim=$(latest vim/vim '^v[0-9]+\.[0-9]+\.[0-9]+$')
ncurses=$(latest ThomasDickey/ncurses-snapshots '^v[0-9]+_[0-9]+$')
ctags=$(latest universal-ctags/ctags-nightly-build '^[0-9]{4}\.[0-9]{2}\.[0-9]{2}\+')
fzf=$(latest junegunn/fzf '^v[0-9]+\.[0-9]+\.[0-9]+$')
sc=$(latest koalaman/shellcheck '^v[0-9]+\.[0-9]+\.[0-9]+$')
rg=$(latest BurntSushi/ripgrep '^[0-9]+\.[0-9]+\.[0-9]+$')
cat > versions.env <<EOV
VIM_VERSION=$vim
NCURSES_VERSION=$ncurses
CTAGS_VERSION=$ctags
FZF_VERSION=$fzf
SHELLCHECK_VERSION=$sc
RG_VERSION=$rg
EOV
