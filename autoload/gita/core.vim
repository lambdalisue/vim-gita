let s:save_cpo = &cpo
set cpo&vim

" Modules
let s:P = gita#utils#import('Prelude')
let s:G = gita#utils#import('VCS.Git')
let s:S = gita#utils#import('VCS.Git.StatusParser')


" Public functions
function! gita#core#new(...) abort " {{{
  " return a new gita instance
  let expr = get(a:000, 0, '%')
  let bufname = bufname(expr)
  let buftype = getbufvar(expr, '&buftype')
  if empty(buftype) && !empty(bufname)
    let git = s:G.find(fnamemodify(bufname, ':p'))
    if empty(git)
      let git = s:G.find(resolve(expand(expr)))
    endif
  elseif !buflisted(bufname) && filereadable(expand(expr))
    let git = s:G.find(fnamemodify(expand(expr), ':p'))
    if empty(git)
      let git = s:G.find(resolve(expand(expr)))
    endif
  else
    " Non file buffer. Use a current working directory instead.
    let git = s:G.find(fnamemodify(getcwd(), ':p'))
  endif
  let gita = extend(deepcopy(s:gita), {
        \ 'enabled': !empty(git),
        \ 'bufname': bufname,
        \ 'bufnum':  bufnr('%'),
        \ 'cwd':     getcwd(),
        \ 'git':     git,
        \})
  let gita.operations = gita#operations#new(gita)
  call setbufvar(expr, '_gita', gita)
  return gita
endfunction " }}}
function! gita#core#get(...) abort " {{{
  " return a cached or new gita instance
  let expr = get(a:000, 0, '%')
  let gita = getwinvar(bufnr(expr), '_gita', {})
  if !empty(gita) && !gita.is_expired()
    return gita
  endif
  let gita = getbufvar(expr, '_gita', {})
  if !empty(gita) && !gita.is_expired()
    return gita
  endif
  return gita#core#new(expr)
endfunction " }}}


" Gita instance
let s:gita = {}
function! s:gita.is_expired() abort " {{{
  let bufnum = get(self, 'bufnum', -1)
  let bufname = bufname(bufnum)
  let buftype = getbufvar(bufnum, '&buftype')
  if empty(buftype) && bufname !=# get(self, 'bufname', '')
    return 1
  elseif !empty(buftype) && getcwd() !=# self.cwd
    return 1
  else
    return 0
  endif
endfunction " }}}
function! s:gita.fail_on_disabled() abort " {{{
  if !self.enabled
    call gita#utils#warn(
          \ 'Gita is not available on the current buffer.',
          \)
    return 1
  endif
  return 0
endfunction " }}}


let &cpo = s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
