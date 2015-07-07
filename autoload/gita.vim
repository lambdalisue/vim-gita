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
  elseif empty(buftype) && bufname !=# self.bufname
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

function! gita#new(...) abort " {{{
  let expr = get(a:000, 0, '%')
  let bufname = bufname(expr)
  let btype = getbufvar(expr, '&l:buftype')
  let ftype = getbufvar(expr, '&l:filetype')
  let filename = gita#utils#expand(expr)
  if !empty(g:gita#invalid_buftype_pattern) && btype =~# g:gita#invalid_buftype_pattern
    let git = {}
  elseif !empty(g:gita#invalid_filetype_pattern) && ftype =~# g:gita#invalid_filetype_pattern
    let git = {}
  elseif filereadable(filename)
    " to follow '_gita_original_filename', use 'expr' and 'gita#utils#expand'
    " instead of guess from bufname
    let git = s:G.find(filename)
    let git = empty(git)
          \ ? s:G.find(resolve(filename))
          \ : git
  else
    let git = s:G.find(getcwd())
  endif
  let gita = extend(deepcopy(s:gita), {
        \ 'enabled':  !empty(git),
        \ 'filename': filename,
        \ 'bufname':  bufname,
        \ 'bufnum':   bufnr(expr),
        \ 'cwd':      getcwd(),
        \ 'git':      git,
        \ 'meta':     {},
        \})
  let gita.operations = gita#operations#new(gita)
  if !empty(getwinvar(bufwinnr(expr), '_gita'))
    call setwinvar(bufwinnr(expr), '_gita', gita)
  else
    call setbufvar(expr, '_gita', gita)
  endif
  return gita
endfunction " }}}
function! gita#get(...) abort " {{{
  let expr = get(a:000, 0, '%')
  let gita = getwinvar(bufwinnr(expr), '_gita', {})
  let gita = empty(gita)
        \ ? getbufvar(expr, '_gita', {})
        \ : gita
  if !empty(gita) && !gita.is_expired()
    return gita
  endif
  return gita#new(expr)
endfunction " }}}
function! gita#get_meta(...) abort " {{{
  let gita = call('gita#get', a:000)
  let gita.meta = get(gita, 'meta', {})
  return gita.meta
endfunction " }}}
function! gita#set_meta(meta, ...) abort " {{{
  let meta = call('gita#get_meta', a:000)
  return extend(meta, a:meta)
endfunction " }}}
function! gita#get_original_filename(...) abort " {{{
  return getbufvar(get(a:000, 0, '%'), '_gita_original_filename', '')
endfunction " }}}
function! gita#set_original_filename(filename, ...) abort " {{{
  call setbufvar(get(a:000, 0, '%'), '_gita_original_filename', a:filename)
endfunction " }}}
function! gita#is_enabled(...) abort " {{{
  return call('gita#get', a:000).enabled
endfunction " }}}
function! gita#force_refresh(...) abort " {{{
  let gita = call('gita#get', a:000)
  let gita.force_expired = 1
endfunction " }}}
function! gita#clear_cache(...) abort " {{{
  let gita = call('gita#get', a:000)
  if gita.enabled
    call gita.git.cache.repository.clear()
  endif
endfunction " }}}

function! s:ac_BufWritePre() abort
  let b:_gita_clear_cache = &modified
endfunction
function! s:ac_BufWritePost() abort
  if get(b:, '_gita_clear_cache')
    call gita#clear_cache()
  endif
  silent! unlet! b:_gita_clear_cache
endfunction

augroup vim-gita-clear-cache
  autocmd! *
  autocmd BufWritePre * call s:ac_BufWritePre()
  autocmd BufWritePost * call s:ac_BufWritePost()
  autocmd User vim-gita-fetch-post call gita#clear_cache()
  autocmd User vim-gita-push-post call gita#clear_cache()
  autocmd User vim-gita-pull-post call gita#clear_cache()
  autocmd User vim-gita-commit-post call gita#clear_cache()
  autocmd User vim-gita-add-post call gita#clear_cache()
  autocmd User vim-gita-rm-post call gita#clear_cache()
  autocmd User vim-gita-reset-post call gita#clear_cache()
  autocmd User vim-gita-merge-post call gita#clear_cache()
  autocmd User vim-gita-rebase-post call gita#clear_cache()
  autocmd User vim-gita-checkout-post call gita#clear_cache()
augroup END


let &cpo = s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
