let s:save_cpo = &cpo
set cpo&vim


let s:hooks = {}
function! s:hooks.call(name, ...) abort " {{{
  if has_key(self, a:name)
    call call(self[a:name], a:000, self)
  endif
endfunction " }}}

function! gita#utils#hooks#new() abort " {{{
  let hooks = deepcopy(s:hooks)
  return hooks
endfunction " }}}
function! gita#utils#hooks#get(...) abort " {{{
  let expr = get(a:000, 0, '%')
  let hooks = getbufvar(expr, '_gita_hooks', {})
  if !empty(hooks)
    return hooks
  endif
  call setbufvar(expr, '_gita_hooks', gita#utils#hooks#new())
  return getbufvar(expr, '_gita_hooks')
endfunction " }}}
function! gita#utils#hooks#call(name, ...) abort " {{{
  let hooks = gita#utils#hooks#get()
  call call(hooks.call, extend([a:name], a:000), hooks)
endfunction " }}}


let &cpo = s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
