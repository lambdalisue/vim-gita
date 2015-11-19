let s:save_cpoptions = &cpoptions
set cpoptions&vim


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
function! gita#utils#hooks#get() abort " {{{
  let hooks = get(b:, '_gita_hooks', {})
  if !empty(hooks)
    return hooks
  endif
  let b:_gita_hooks = gita#utils#hooks#new()
  return b:_gita_hooks
endfunction " }}}
function! gita#utils#hooks#call(name, ...) abort " {{{
  let hooks = gita#utils#hooks#get()
  call call(hooks.call, extend([a:name], a:000), hooks)
endfunction " }}}
function! gita#utils#hooks#register(name, fn) abort " {{{
  let hooks = gita#utils#hooks#get()
  let hooks[a:name] = a:fn
endfunction " }}}


let &cpoptions = s:save_cpoptions
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
