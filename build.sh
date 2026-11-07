#!/bin/sh
# Build dist/vimzip-linux-x86_64.{zip,tar.gz}
set -eu
cd "$(dirname "$0")"
R=$PWD
D=$R/build/vimzip
rm -rf "$D" && mkdir -p "$D" "$R/dist"

scripts/build-vim.sh "$D"
scripts/fetch.sh "$D"

for p in pack/vimzip/start/*/; do
  cp -r "$p" "$D/pack/vimzip/start/"
done
find "$D/pack" -depth \( -name .git -o -name .github -o -name test -o -name tests \) -exec rm -rf {} +
cp vimrc "$D/vimrc"
cp vim install.sh "$D/"

# smoke test + help tags
VIMZIP=$D VIMRUNTIME=$D/runtime "$D/bin/vim" -u "$D/vimrc" -i NONE -es \
  -c 'helptags ALL' -c 'if !exists(":ALEInfo") | cquit | endif' -c 'qa!'
"$D/bin/vim" --version | head -n 2

cd "$R/build"
rm -f "$R"/dist/vimzip-linux-x86_64.*
zip -qr9 "$R/dist/vimzip-linux-x86_64.zip" vimzip
tar -czf "$R/dist/vimzip-linux-x86_64.tar.gz" vimzip
ls -l "$R"/dist/vimzip-linux-x86_64.*
