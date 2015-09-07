let s:save_cpo = &cpo
set cpo&vim

let s:history = { 'history': [], 'index': -2 }
function! s:history.add() abort " {{{
  let pos = extend([bufnr('%')], getpos('.')[1:])
  call add(self.history, pos)
  let self.index = -2
endfunction " }}}
function! s:history.next() abort " {{{
  if len(self.history) == 0
    return
  endif
  let index = self.index + 1
  if self.index == -2 || index >= len(self.history)
    let index = len(self.history) - 1
  elseif index < 0
    let index = 0
  endif
  let [bufnum, lnum, col, off] = self.history[index]
  execute printf('keepjumps %dbuffer', bufnum)
  keepjumps call setpos('.', [0, lnum, col, off])
  let self.index = index
endfunction " }}}
function! s:history.previous() abort " {{{
  if len(self.history) == 0
    return
  endif
  let index = self.index - 1
  if self.index == -2 || index >= len(self.history)
    let index = len(self.history) - 1
  elseif index < 0
    let index = 0
  endif
  let [bufnum, lnum, col, off] = self.history[index]
  execute printf('keepjumps %dbuffer', bufnum)
  keepjumps call setpos('.', [0, lnum, col, off])
  let self.index = index
endfunction " }}}

function! gita#utils#history#new() abort " {{{
  return deepcopy(s:history)
endfunction " }}}

let &cpo = s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
