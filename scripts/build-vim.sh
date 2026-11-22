#!/bin/sh
# Build a static vim (musl + ncurses) into $1 (bin/, runtime/).
set -eu
cd "$(dirname "$0")/.."
. ./versions.env
OUT=$(mkdir -p "$1" && cd "$1" && pwd)
CC=${CC:-cc}
J=$(nproc)
W=$(mktemp -d)
trap 'rm -rf "$W"' EXIT

clone() {  # retry: GitHub has short outages
  for i in 1 2 3 4; do
    git clone -q --depth 1 -b "$1" "$2" "$3" && return 0
    rm -rf "$3"; sleep $((i * 5))
  done
  return 1
}
clone "$NCURSES_VERSION" https://github.com/ThomasDickey/ncurses-snapshots "$W/ncurses"
clone "$VIM_VERSION" https://github.com/vim/vim "$W/vim"

cd "$W/ncurses"
./configure -q CC="$CC" --prefix="$W/nc" \
  --without-shared --without-debug --without-ada --without-cxx --without-cxx-binding \
  --without-manpages --without-progs --without-tests --disable-db-install --enable-widec \
  --with-terminfo-dirs=/etc/terminfo:/lib/terminfo:/usr/share/terminfo:/usr/lib/terminfo \
  --with-default-terminfo-dir=/usr/share/terminfo \
  --with-fallbacks=linux,vt100,vt220,xterm,xterm-color,xterm-256color,screen,screen-256color,tmux,tmux-256color
make -s -j"$J" >/dev/null
make -s install >/dev/null

# GNU libiconv for vim's encoding conversions: musl's iconv only reads CJK encodings, so a file in
# CP949, EUC-KR, Shift-JIS or GBK opened fine but could not be saved (E213). ICONV_PREFIX: use an
# installed one instead.
if [ -z "${ICONV_PREFIX:-}" ]; then
  mkdir -p "$W/libiconv"
  for i in 1 2 3 4; do
    curl -fsSL "https://ftp.gnu.org/pub/gnu/libiconv/libiconv-$LIBICONV_VERSION.tar.gz" |
      tar -xz -C "$W/libiconv" --strip-components=1 && break
    sleep $((i * 5))
  done
  (cd "$W/libiconv" && ./configure -q CC="$CC" --prefix="$W/iconv" --enable-static --disable-shared --disable-nls &&
    make -s -j"$J" >/dev/null && make -s install >/dev/null)
  ICONV_PREFIX=$W/iconv
fi

cd "$W/vim"
PKG_CONFIG=false ./configure -q CC="$CC" --prefix=/usr \
  CPPFLAGS="-I$ICONV_PREFIX/include -I$W/nc/include -I$W/nc/include/ncursesw" \
  LDFLAGS="-static -L$ICONV_PREFIX/lib -L$W/nc/lib" \
  --with-features=huge --with-tlib=ncursesw --enable-multibyte \
  --disable-gui --without-x --disable-gpm --disable-sysmouse --disable-nls --disable-acl \
  --disable-selinux --disable-smack --disable-canberra --disable-libsodium --disable-xsmp --disable-pixman
make -s -j"$J" >/dev/null
make -s install DESTDIR="$W/inst" >/dev/null

mkdir -p "$OUT/bin"
cp "$W/inst/usr/bin/vim" "$W/inst/usr/bin/xxd" "$OUT/bin/"
strip "$OUT/bin/vim" "$OUT/bin/xxd"
rm -rf "$OUT/runtime"
cp -r "$W"/inst/usr/share/vim/vim[0-9]* "$OUT/runtime"
