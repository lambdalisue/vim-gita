let s:save_cpo = &cpo
set cpo&vim

" Modules
let s:Git = gita#utils#import('VCS.Git')

" Private functions
function! s:new_gita(...) abort " {{{
  let expr = get(a:000, 0, '%')
  if !bufexists(expr)
    throw printf(
          \ 'vim-gita: the buffer "%s" does not exist',
          \ expr,
          \)
  endif
  let buftype = getbufvar(expr, '&buftype')
  if empty(buftype)
    let git = s:Git.find(fnamemodify(bufname(expr), ':p'))
    let gita = extend(deepcopy(s:gita), {
          \ 'enabled': !empty(git),
          \ 'bufname': bufname(expr),
          \ 'bufnum': bufnr(expr),
          \ 'cwd': getcwd(),
          \ 'git': git,
          \})
  else
    " Non file buffer. Use a current working directory instead.
    let git = s:Git.find(fnamemodify(getcwd(), ':p'))
    let gita = extend(deepcopy(s:gita), {
          \ 'enabled': !empty(git),
          \ 'bufname': bufname(expr),
          \ 'bufnum': bufnr(expr),
          \ 'cwd': getcwd(),
          \ 'git': git,
          \})
  endif
  call setbufvar(expr, '_gita', gita)
  return gita
endfunction " }}}
function! s:get_gita(...) abort " {{{
  let expr = get(a:000, 0, '%')
  if !bufexists(expr)
    throw printf(
          \ 'vim-gita: the buffer "%s" does not exist',
          \ expr,
          \)
  endif
  let gita = getbufvar(expr, '_gita', {})
  if empty(gita) || gita.is_expired()
    return s:new_gita(expr)
  else
    return gita
  endif
endfunction " }}}


" Public functions
function! gita#core#new(...) abort " {{{
  " return a new gita instance
  return call('s:new_gita', a:000)
endfunction " }}}
function! gita#core#get(...) abort " {{{
  " return a cached or new gita instance
  return call('s:get_gita', a:000)
endfunction " }}}

" Gita instance
let s:gita = {}
function! s:gita.is_expired() abort " {{{
  let bufname = bufname(self.bufnum)
  let buftype = getbufvar(self.bufnum, '&buftype')
  if empty(buftype) && bufname !=# self.bufname
    return 1
  elseif !empty(buftype) && getcwd() !=# self.cwd
    return 1
  else
    return 0
  endif
endfunction " }}}

let &cpo = s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
