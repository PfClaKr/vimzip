#!/bin/sh
# Put vimzip's vim on PATH and make it the default editor.
set -eu
D=$(dirname "$(readlink -f "$0")")
mkdir -p "$HOME/.local/bin"
ln -sf "$D/vim" "$HOME/.local/bin/vim"
case ${SHELL:-} in
  *zsh) rc=$HOME/.zshrc ;;
  *) rc=$HOME/.bashrc ;;
esac
if ! grep -q '# vimzip' "$rc" 2>/dev/null; then
  printf '\n# vimzip\nexport PATH="$HOME/.local/bin:$PATH"\nexport EDITOR=vim\n' >> "$rc"
fi
echo "vimzip: installed. Open a new shell (or: . $rc), then run: vim ."
