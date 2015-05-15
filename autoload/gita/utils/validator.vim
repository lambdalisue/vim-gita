let s:save_cpo = &cpo
set cpo&vim

let s:validator = {}
function! s:validator.validate(status, option) abort " {{{
  throw 'vim-gita: Sub class must override "validate" function.'
endfunction " }}}

function! gita#utils#validator#new(...) abort " {{{
  let validator = extend(deepcopy(s:validator), get(a:000, 0, {}))
  return validator
endfunction " }}}

let &cpo = s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
