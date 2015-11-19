let s:save_cpoptions = &cpoptions
set cpoptions&vim

let s:V = vital#of('vim_gita')
function! gita#import(name) abort
  let cache_name = printf(
        \ '_vital_module_%s',
        \ substitute(a:name, '\.', '_', 'g'),
        \)
  if !has_key(s:, cache_name)
    let s:[cache_name] = s:V.import(a:name)
  endif
  return s:[cache_name]
endfunction

let s:P = gita#import('System.Filepath')
let s:G = gita#import('VCS.Git')
let s:file = expand('<sfile>:p')
let s:repo = fnamemodify(s:file, ':h')


let s:gita = {}
function! s:gita.is_expired() abort " {{{
  let bufnum = get(self, 'bufnum', -1)
  let bufname = bufname(bufnum)
  let buftype = gita#compat#getbufvar(bufnum, '&buftype')
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
    call gita#utils#prompt#warn(
          \ 'Gita is not available on the current buffer.',
          \)
    return 1
  endif
  return 0
endfunction " }}}

function! gita#new(...) abort " {{{
  let expr = get(a:000, 0, '%')
  let bufname = bufname(expr)
  let filename = gita#utils#path#expand(expr)
  if filereadable(filename)
    let git = s:G.find(filename)
    let git = empty(git)
          \ ? s:G.find(resolve(filename))
          \ : git
  else
    let git = s:G.find(getcwd())
  endif
  let gita = extend(deepcopy(s:gita), {
        \ 'enabled':  !empty(git),
        \ 'bufname':  bufname,
        \ 'bufnum':   bufnr(expr),
        \ 'cwd':      getcwd(),
        \ 'git':      git,
        \})
  let gita.operations = gita#operations#new(gita)
  " store timestamp of repository cache for debugging
  if !empty(git)
    let git.cache.repository._timestamp =
          \ get(git.cache.repository, '_timestamp', localtime())
  endif
  if bufexists(bufnr(expr))
    if empty(bufname)
      call setbufvar(expr, '_gita', gita)
    else
      call setwinvar(bufwinnr(expr), '_gita', gita)
    endif
  endif
  return gita
endfunction " }}}
function! gita#get(...) abort " {{{
  let expr = get(a:000, 0, '%')
  let gita = gita#compat#getwinvar(bufwinnr(expr), '_gita', {})
  let gita = empty(gita)
        \ ? gita#compat#getbufvar(expr, '_gita', {})
        \ : gita
  if !empty(gita) && !gita.is_expired()
    return gita
  endif
  return gita#new(expr)
endfunction " }}}
function! gita#is_enabled(...) abort " {{{
  return call('gita#get', a:000).enabled
endfunction " }}}
function! gita#force_refresh(...) abort " {{{
  let gita = call('gita#get', a:000)
  let gita.force_expired = 1
endfunction " }}}
function! gita#clear_repository_cache(...) abort " {{{
  let gita = call('gita#get', a:000)
  if gita.enabled
    call gita.git.cache.repository.clear()
    " store timestamp of repository cache for debugging
    let gita.git.cache.repository._timestamp = localtime()
  endif
endfunction " }}}
function! gita#clear_finder_cache() abort " {{{
  let gita = call('gita#get', a:000)
  call s:G.get_finder().clear()
endfunction " }}}
function! gita#clear_cache() abort " {{{
  call gita#clear_finder_cache()
  silent! unlet! b:_gita
  silent! unlet! w:_gita
endfunction " }}}

function! gita#preload(path) abort " {{{
  let abspath = s:P.join(
        \ s:repo,
        \ substitute(a:path, '\#', s:P.separator(), 'g'),
        \)
  execute printf('source %s.vim', abspath)
endfunction " }}}

augroup vim-gita-clear-cache
  autocmd! *
  autocmd User vim-gita-fetch-post call gita#clear_repository_cache()
  autocmd User vim-gita-push-post call gita#clear_repository_cache()
  autocmd User vim-gita-pull-post call gita#clear_repository_cache()
  autocmd User vim-gita-commit-post call gita#clear_repository_cache()
  autocmd User vim-gita-add-post call gita#clear_repository_cache()
  autocmd User vim-gita-rm-post call gita#clear_repository_cache()
  autocmd User vim-gita-reset-post call gita#clear_repository_cache()
  autocmd User vim-gita-merge-post call gita#clear_repository_cache()
  autocmd User vim-gita-rebase-post call gita#clear_repository_cache()
  autocmd User vim-gita-checkout-post call gita#clear_repository_cache()
augroup END

let &cpoptions = s:save_cpoptions
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
