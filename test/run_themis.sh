#!/usr/bin/env bash
: ${VIMTHEMIS:=~/.vim/bundle/vim-themis}
: ${VIMPROC:=~/.vim/bundle/vimproc.vim}

# themis
sh ${VIMTHEMIS}/bin/themis \
     --reporter spec \
     --runtimepath ${VIMPROC} \
     $@

