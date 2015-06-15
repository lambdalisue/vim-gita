let s:save_cpo = &cpo
set cpo&vim


let s:hooks = {}
function! s:hooks.call(name, ...) abort " {{{
  if has_key(self, a:name)
    call call(self[a:name], a:000, self.__parent)
  endif
endfunction " }}}


function! gita#utils#hooks#new(...) abort " {{{
  let hooks = deepcopy(s:hooks)
  let hooks.__parent = get(a:000, 0, hooks)
  return hooks
endfunction " }}}


let &cpo = s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
