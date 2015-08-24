#!/bin/bash
set -e
if [ "$HEAD" = "yes" ]; then
  git clone --depth 1 https://github.com/vim-jp/vim /tmp/vim
  cd /tmp/vim
  ./configure \
      --prefix="$HOME/vim" \
      --enable-fail-if-missing \
      --with-features=huge \
      --enable-perlinterp \
      --enable-pythoninterp \
      --enable-python3interp \
      --enable-rubyinterp \
      --enable-luainterp
  make -j2
  make install
fi
