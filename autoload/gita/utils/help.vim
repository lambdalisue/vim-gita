let s:save_cpo = &cpo
set cpo&vim

" Modules
let s:scriptfile = expand('<sfile>')
let s:P = gita#utils#import('System.Filepath')


" Private functions
function! s:get_help_directory() abort " {{{
  let repository_root = fnamemodify(s:scriptfile, ':h:h:h:h:p')
  return s:P.join(repository_root, 'help')
endfunction " }}}
function! s:read(name) abort " {{{
  let cache_name = printf('_help_%s_cache', a:name)
  if !has_key(s:, cache_name)
    let filename = s:P.join(s:get_help_directory(), a:name . '.txt')
    if !filereadable(filename)
      throw printf(
            \ 'vim-gita: No help file "%s" is found.',
            \ filename,
            \)
    endif
    let s:[cache_name] = readfile(filename)
  endif
  return s:[cache_name]
endfunction " }}}
function! s:is_enabled(name) abort " {{{
  let varname = printf('_help_%s_enabled', a:name)
  return get(b:, varname, 0)
endfunction " }}}
function! s:enable(name) abort " {{{
  let varname = printf('_help_%s_enabled', a:name)
  let b:[varname] = 1
endfunction " }}}
function! s:disable(name) abort " {{{
  let varname = printf('_help_%s_enabled', a:name)
  let b:[varname] = 0
endfunction " }}}
function! s:toggle(name) abort " {{{
  let varname = printf('_help_%s_enabled', a:name)
  let b:[varname] = !get(b:, varname, 0)
endfunction " }}}
function! s:get(name) abort " {{{
  if s:is_enabled(a:name)
    return s:read(a:name)
  else
    return []
  endif
endfunction " }}}


" Public functions
function! gita#utils#help#read(...) abort " {{{
  return call('s:read', a:000)
endfunction " }}}
function! gita#utils#help#is_enabled(...) abort " {{{
  return call('s:is_enabled', a:000)
endfunction " }}}
function! gita#utils#help#enable(...) abort " {{{
  return call('s:enable', a:000)
endfunction " }}}
function! gita#utils#help#disable(...) abort " {{{
  return call('s:disable', a:000)
endfunction " }}}
function! gita#utils#help#toggle(...) abort " {{{
  return call('s:toggle', a:000)
endfunction " }}}
function! gita#utils#help#get(...) abort " {{{
  return call('s:get', a:000)
endfunction " }}}


let &cpo = s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
