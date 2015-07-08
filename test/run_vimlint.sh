#!/usr/bin/env bash
: ${VIMLINT:=~/.vim/bundle/vim-vimlint}
: ${VIMLPARSER:=~/.vim/bundle/vim-vimlparser}

# vim-vimlint
sh ${VIMLINT}/bin/vimlint.sh \
    -l ${VIMLINT} -p ${VIMLPARSER} \
    -e EVL103=1 -e EVL102.l:_=1 -c func_abort=1 \
    autoload
