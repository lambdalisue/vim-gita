#!/usr/bin/env bash
: ${VIMTHEMIS:=~/.vim/bundle/vim-themis}
: ${VIMPROC:=~/.vim/bundle/vimproc.vim}
: ${VITALVIM:=~/.vim/bundle/vital.vim}

# themis
sh ${VIMTHEMIS}/bin/themis \
     --reporter dot \
     --runtimepath ${VIMPROC} \
     --runtimepath ${VITALVIM} \
     $@

