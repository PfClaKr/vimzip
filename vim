#!/bin/sh
D=$(dirname "$(readlink -f "$0")")
export VIMZIP="$D" VIMRUNTIME="$D/runtime" PATH="$D/bin:$PATH"
exec "$D/bin/vim" -u "$D/vimrc" "$@"
