#!/bin/sh
D=$(dirname "$(readlink -f "$0")")
export VIMZIP="$D" VIMRUNTIME="$D/runtime" PATH="$D/bin:$PATH"
# Can the terminal scroll between left and right margins (DECSLRM)? Then windows side by side
# scroll instead of redrawing every line (see vimrc). Asked with DECRQM; the DA1 query after it,
# which every terminal answers, ends the wait. VIMZIP_DECSLRM=0 or 1 skips the question.
if [ -z "$VIMZIP_DECSLRM" ] && [ -t 0 ] && [ -t 1 ] && [ -z "$TMUX$STY" ]; then
  VIMZIP_DECSLRM=0
  if old=$(stty -g 2>/dev/null) && stty raw -echo min 0 time 5 2>/dev/null; then
    printf '\033[?69$p\033[c'
    r=
    for _ in 1 2 3; do
      got=$(dd bs=64 count=1 2>/dev/null)
      r="$r$got"
      case $r in *c) break ;; esac
      [ -n "$got" ] || break
    done
    stty "$old"
    case $r in *'[?69;'[12]'$y'*) VIMZIP_DECSLRM=1 ;; esac
  fi
  export VIMZIP_DECSLRM
fi
exec "$D/bin/vim" -u "$D/vimrc" "$@"
