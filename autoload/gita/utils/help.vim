let s:save_cpo = &cpo
set cpo&vim

let s:scriptfile = expand('<sfile>')

function! s:get_help_directory() abort " {{{
endfunction " }}}

let &cpo = s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
