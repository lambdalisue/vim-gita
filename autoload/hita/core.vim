let s:save_cpo = &cpo
set cpo&vim

let s:V = hita#vital()
let s:Compat = s:V.import('Vim.Compat')
let s:Git = s:V.import('VCS.Git')

let s:hita = {}
function! s:hita.is_expired() abort
  let bufnum = get(self, 'bufnum', -1)
  let bufname = bufname(bufnum)
  let buftype = s:Compat.getbufvar(bufnum, '&buftype')
  if empty(buftype) && bufname !=# self.bufname
    return 1
  elseif (!empty(buftype) || empty(bufname)) && getcwd() !=# self.cwd
    return 1
  else
    return 0
  endif
endfunction
function! s:hita.fail_on_disabled() abort
  if !self.enabled
    call hita#util#prompt#echo(
          \ 'WarningMsg',
          \ 'Hita is not available on the current buffer.',
          \)
    return 1
  endif
  return 0
endfunction

function! hita#core#new(...) abort
  let expr = get(a:000, 0, '%')
  let bufname = bufname(expr)
  let filename = hita#expand(expr)
  if filereadable(filename)
    let git = s:Git.find(filename)
    let git = empty(git)
          \ ? s:Git.find(resolve(filename))
          \ : git
  else
    let git = s:Git.find(getcwd())
  endif
  let hita = extend(deepcopy(s:hita), {
        \ 'enabled': !empty(git),
        \ 'bufname': bufname,
        \ 'bufnum':  bufnr(expr),
        \ 'cwd':     getcwd(),
        \ 'git':     git,
        \})
  if bufexists(bufnr(expr))
    call setbufvar(expr, '_hita', hita)
  endif
  return hita
endfunction
function! hita#core#get(...) abort
  let expr = get(a:000, 0, '%')
  let hita = s:Compat.getbufvar(expr, '_hita', {})
  if !empty(hita) && !hita.is_expired()
    return hita
  endif
  return hita#core#new(expr)
endfunction
function! hita#core#is_enabled(...) abort
  let hita = call('hita#core#get', a:000)
  return hita.enabled
endfunction

let &cpo = s:save_cpo
unlet! s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
