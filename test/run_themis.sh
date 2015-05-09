#!/usr/bin/env bash
themis --reporter dot \
       --runtimepath $HOME/.vim/bundle/vital.vim \
       --runtimepath $HOME/.vim/bundle/vimproc.vim \
       $@

