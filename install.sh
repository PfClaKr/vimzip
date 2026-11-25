#!/bin/sh
# Put vimzip on PATH, asking a few things first (Enter keeps the choice in brackets):
#   how to start it: as vim (in place of vim) or as vimzip (vim stays as it is)
#   whether git and other programs open it (EDITOR, VISUAL)
#   the status bar's theme, closing brackets, formatting on save, line blame, the AI agent
# The choices go to ~/.config/vimzip/vimrc (change them there any time) and the shell's rc file.
#
#   install.sh             ask
#   install.sh --yes       no questions: the choices in brackets (also when not run in a terminal)
#   install.sh --uninstall take the links and the rc lines away (~/vimzip and the settings stay)
set -eu
D=$(dirname "$(readlink -f "$0")")
BIN=$HOME/.local/bin
CONF=${XDG_CONFIG_HOME:-$HOME/.config}/vimzip
case ${SHELL:-} in
  *zsh) rc=$HOME/.zshrc ;;
  *fish) rc=${XDG_CONFIG_HOME:-$HOME/.config}/fish/config.fish ;;
  *) rc=$HOME/.bashrc ;;
esac

ask=1
case ${1:-} in
  --yes|-y) ask=0 ;;
  --uninstall) ask=uninstall ;;
  '') ;;
  *) echo "usage: install.sh [--yes | --uninstall]" >&2; exit 2 ;;
esac
[ -t 0 ] || [ "$ask" = uninstall ] || ask=0

# the rc file's lines between the markers taken away (and the 3 lines an older install wrote)
unrc() {
  [ -f "$rc" ] || return 0
  awk '
    /^# vimzip start$/ { skip = 1; next }
    /^# vimzip end$/ { skip = 0; next }
    /^# vimzip$/ { old = 2; next }
    old > 0 && /^export (PATH|EDITOR)=/ { old--; next }
    { old = 0 } !skip
  ' "$rc" > "$rc.vimzip-tmp" && cat "$rc.vimzip-tmp" > "$rc" && rm -f "$rc.vimzip-tmp"
}
# the links that point into this vimzip
unlink_all() {
  for n in vim vi view vimdiff vimzip; do
    if [ -L "$BIN/$n" ] && [ "$(readlink -f "$BIN/$n")" = "$D/vim" ]; then rm -f "$BIN/$n"; fi
  done
}

if [ "$ask" = uninstall ]; then
  unlink_all
  # (and the programs of yours install.sh set aside, back)
  for n in vim vi view vimdiff vimzip; do
    if [ -e "$BIN/$n.before-vimzip" ] && [ ! -e "$BIN/$n" ]; then mv "$BIN/$n.before-vimzip" "$BIN/$n"; fi
  done
  unrc
  echo "vimzip: uninstalled (links and $rc lines). Left: $D, $CONF, ~/.cache/vimzip"
  exit 0
fi

# choose VAR "question" default "choice: what it means" ...  (a number or the choice's name)
choose() {
  _var=$1 _q=$2 _def=$3
  shift 3
  if [ "$ask" = 1 ]; then
    printf '\n%s\n' "$_q"
    _i=1
    for _c in "$@"; do printf '  %d) %s\n' "$_i" "$_c"; _i=$((_i + 1)); done
  fi
  while :; do
    _ans=
    if [ "$ask" = 1 ]; then printf '[%s] ' "$_def"; read -r _ans || _ans=; fi
    [ -n "$_ans" ] || _ans=$_def
    _i=1
    for _c in "$@"; do
      _n=${_c%%:*}
      if [ "$_ans" = "$_i" ] || [ "$_ans" = "$_n" ]; then eval "$_var=\$_n"; return; fi
      _i=$((_i + 1))
    done
    echo "  (one of 1-$((_i - 1)))"
    [ "$ask" = 1 ] || exit 1
  done
}
# yesno VAR "question" y|n
yesno() {
  _var=$1 _q=$2 _def=$3
  while :; do
    _ans=
    if [ "$ask" = 1 ]; then printf '\n%s [%s] ' "$_q" "$([ "$_def" = y ] && echo Y/n || echo y/N)"; read -r _ans || _ans=; fi
    case ${_ans:-$_def} in
      [Yy]*) eval "$_var=1"; return ;;
      [Nn]*) eval "$_var=0"; return ;;
    esac
  done
}

# (the choices in brackets, set by the questions below)
name=vim editor=1 theme=gray pairs=1 format=auto blame=1 ai=auto
[ "$ask" = 1 ] && echo "vimzip setup: Enter keeps the choice in brackets."
choose name "How do you start it?" vim \
  "vim: in place of vim for you (vim, vi, view, vimdiff)" \
  "vimzip: as the command vimzip; vim stays as it is"
yesno editor "Do git and other programs open it (EDITOR, VISUAL)?" y
set --
for t in "$D"/themes/*.vim; do
  [ -f "$t" ] && set -- "$@" "$(basename "$t" .vim)"
done
choose theme "The status bar's colors (:Theme tries them later)" gray "$@"
yesno pairs "Close brackets and quotes as you type them?" y
choose format "Format a file when you save it?" auto \
  "auto: when the project has the formatter's settings (.clang-format, .prettierrc...)" \
  "always: whenever a formatter for its language is installed" \
  "never: only with Space cf"
yesno blame "Show who last changed the line (git) at the end of it?" y
choose ai "The AI agent for Space a" auto \
  "auto: the first installed of claude, codex, gemini, aider, opencode" \
  "claude" "codex" "gemini" "aider" "opencode"

# the links
mkdir -p "$BIN"
unlink_all
# (a program of yours by that name, not a link: kept beside it, not overwritten)
link() {
  if [ -e "$BIN/$1" ] && [ ! -L "$BIN/$1" ]; then
    mv "$BIN/$1" "$BIN/$1.before-vimzip"
    echo "vimzip: your $BIN/$1 is now $BIN/$1.before-vimzip"
  fi
  ln -sf "$D/vim" "$BIN/$1"
}
if [ "$name" = vim ]; then
  for n in vim vi view vimdiff; do link "$n"; done
else
  link vimzip
fi

# the shell: PATH where it is not yet, and EDITOR
unrc
mkdir -p "$(dirname "$rc")"
{
  echo "# vimzip start"
  case $rc in
    *.fish)
      echo "fish_add_path -g \$HOME/.local/bin"
      [ "$editor" = 1 ] && echo "set -gx EDITOR $name; set -gx VISUAL $name" ;;
    *)
      echo "case :\$PATH: in *:\$HOME/.local/bin:*) ;; *) export PATH=\"\$HOME/.local/bin:\$PATH\" ;; esac"
      [ "$editor" = 1 ] && echo "export EDITOR=$name VISUAL=$name" ;;
  esac
  echo "# vimzip end"
} >> "$rc"

# the settings, kept between markers in the user's own vimrc (the rest of it untouched)
mkdir -p "$CONF"
v=$CONF/vimrc
if [ -f "$v" ]; then
  awk '/^" vimzip install start/ { skip = 1; next } /^" vimzip install end$/ { skip = 0; next } !skip' "$v" > "$v.vimzip-tmp"
  cat "$v.vimzip-tmp" > "$v" && rm -f "$v.vimzip-tmp"
fi
fmt=$(case $format in auto) echo "'auto'" ;; always) echo 1 ;; *) echo 0 ;; esac)
{
  echo '" vimzip install start (install.sh wrote these; change them here or run it again)'
  echo "let g:vimzip_theme = '$theme'"
  echo "let g:vimzip_autopairs = $pairs"
  echo "let g:vimzip_format_on_save = $fmt"
  echo "let g:vimzip_blame = $blame"
  [ "$ai" = auto ] || echo "let g:vimzip_ai = '$ai'"
  echo '" vimzip install end'
} >> "$v"

echo
echo "vimzip: installed as '$name'. Settings: $v"
echo "Open a new shell (or: . $rc), then run: $name ."
