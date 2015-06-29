let s:save_cpo = &cpo
set cpo&vim

let s:P = gita#utils#import('Prelude')
let s:G = gita#utils#import('VCS.Git')
let s:S = gita#utils#import('VCS.Git.StatusParser')


let s:gita = {}
function! s:gita.is_expired() abort " {{{
  let bufnum = get(self, 'bufnum', -1)
  let bufname = bufname(bufnum)
  let buftype = getbufvar(bufnum, '&buftype')
  if get(self, 'force_expired')
    return 1
  elseif empty(buftype) && bufname !=# get(self, 'bufname', '')
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

function! gita#core#new(...) abort " {{{
  " return a new gita instance
  let expr = get(a:000, 0, '%')
  let bufname = bufname(expr)
  let buftype = getbufvar(expr, '&l:buftype')
  if buftype =~# '^%\(quickfix\|help\)$'
    " disable Gita in vim's special window
    return { 'enabled': 0 }
  elseif empty(buftype) && !empty(bufname)
    let git = s:G.find(fnamemodify(bufname, ':p'))
    if empty(git)
      let git = s:G.find(resolve(gita#utils#expand(expr)))
    endif
  elseif !buflisted(bufname) && filereadable(gita#utils#expand(expr))
    let git = s:G.find(fnamemodify(gita#utils#expand(expr), ':p'))
    if empty(git)
      let git = s:G.find(resolve(gita#utils#expand(expr)))
    endif
  elseif getbufvar(expr, '_gita_original_filename')
    let git = s:G.find(fnamemodify(getbufvar(expr, '_gita_original_filename'), ':p'))
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
  if getbufvar(expr, '&l:buftype') =~# '^\%(quickfix\|help\)$'
    " disable Gita in vim's special window AS SOON AS POSSIBLE
    return { 'enabled': 0 }
  endif
  let gita = getwinvar(bufwinnr(expr), '_gita', {})
  if empty(gita)
    let gita = getbufvar(expr, '_gita', {})
  endif
  if !empty(gita) && !gita.is_expired()
    return gita
  endif
  return gita#core#new(expr)
endfunction " }}}
function! gita#core#is_enabled(...) abort " {{{
  return call('gita#core#get', a:000).enabled
endfunction " }}}
function! gita#core#force_refresh(...) abort " {{{
  let gita = call('gita#core#get', a:000)
  let gita.force_expired = 1
endfunction " }}}
function! gita#core#clear_cache(...) abort " {{{
  let gita = call('gita#core#get', a:000)
  if gita.enabled
    call gita.git.cache.repository.clear()
  endif
endfunction " }}}

augroup vim-gita-core
  autocmd! *
  autocmd BufWritePost * call gita#core#clear_cache()
  autocmd User vim-gita-fetch-post call gita#core#clear_cache()
  autocmd User vim-gita-push-post call gita#core#clear_cache()
  autocmd User vim-gita-pull-post call gita#core#clear_cache()
  autocmd User vim-gita-commit-post call gita#core#clear_cache()
  autocmd User vim-gita-add-post call gita#core#clear_cache()
  autocmd User vim-gita-rm-post call gita#core#clear_cache()
  autocmd User vim-gita-reset-post call gita#core#clear_cache()
  autocmd User vim-gita-merge-post call gita#core#clear_cache()
  autocmd User vim-gita-rebase-post call gita#core#clear_cache()
  autocmd User vim-gita-checkout-post call gita#core#clear_cache()
augroup END


let &cpo = s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
