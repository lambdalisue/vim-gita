#!/bin/sh
set -e

if [[ $TRAVIS_OS_NAME == 'osx' ]]; then
    brew update
    brew install macvim --with-override-system-vim
else
  git clone --depth 1 https://github.com/vim/vim /tmp/vim
  cd /tmp/vim
  ./configure --prefix="$HOME/vim" \
      --enable-fail-if-missing \
      --with-features=huge \
      --enable-luainterp \
      --enable-pythoninterp \
      --enable-python3interp \
      --enable-multibyte
  make -j 2
  make install
  export PATH="$HOME/vim/bin:$PATH"
fi
