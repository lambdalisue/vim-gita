let s:save_cpo = &cpo
set cpo&vim


" Private functions
function! s:new() abort " {{{
  let bufnum = bufnr('%')
  let winnum = bufwinnr(bufnum)
  let invoker = extend(deepcopy(s:invoker), {
        \ 'bufnum': bufnum,
        \ 'winnum': winnum,
        \})
  return invoker
endfunction " }}}
function! s:get() abort " {{{
  let invoker = get(w:, '_gita_invoker', {})
  if empty(invoker)
    let invoker = s:new()
  endif
  return invoker
endfunction " }}}
function! s:set(invoker) abort " {{{
  let w:_gita_invoker = a:invoker
endfunction " }}}
function! s:clear() abort " {{{
  if has_key(w:, '_gita_invoker')
    unlet w:_gita_invoker
  endif
endfunction " }}}


" Instance
let s:invoker = {}
function! s:invoker.get_winnum() abort " {{{
  let bufnum = self.bufnum
  let winnum = bufwinnr(bufnum)
  if winnum == -1
    let winnum = self.winnum
  endif
  return winnum
endfunction " }}}
function! s:invoker.update_winnum() abort " {{{
  let bufnum = self.bufnum
  let self.winnum = bufwinnr(bufnum)
endfunction " }}}
function! s:invoker.focus() abort " {{{
  let winnum = self.get_winnum()
  if winnum <= winnr('$')
    silent execute winnum . 'wincmd w'
  else
    " invoker is missing. assume a previous window is an invoker
    silent execute 'wincmd p'
  endif
endfunction " }}}


" Public functions
function! gita#utils#invoker#new(...) abort " {{{
  return call('s:new', a:000)
endfunction " }}}
function! gita#utils#invoker#get(...) abort " {{{
  return call('s:get', a:000)
endfunction " }}}
function! gita#utils#invoker#set(...) abort " {{{
  return call('s:set', a:000)
endfunction " }}}
function! gita#utils#invoker#clear(...) abort " {{{
  return call('s:clear', a:000)
endfunction " }}}
function! gita#utils#invoker#focus(...) abort "{{{
  let invoker = call('s:get', a:000)
  call invoker.focus()
endfunction " }}}


let &cpo = s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
