let s:save_cpo = &cpo
set cpo&vim

" Modules
let s:scriptfile = expand('<sfile>')
let s:P = gita#utils#import('System.Filepath')


function! s:get_help_directory() abort " {{{
  let repository_root = fnamemodify(s:scriptfile, ':h:h:h:h:p')
  return s:P.join(repository_root, 'help')
endfunction " }}}


function! gita#utils#help#read(name) abort " {{{
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
function! gita#utils#help#is_enabled(name) abort " {{{
  let varname = printf('_help_%s_enabled', a:name)
  return get(b:, varname, 0)
endfunction " }}}
function! gita#utils#help#enable(name) abort " {{{
  let varname = printf('_help_%s_enabled', a:name)
  let b:[varname] = 1
endfunction " }}}
function! gita#utils#help#disable(name) abort " {{{
  let varname = printf('_help_%s_enabled', a:name)
  let b:[varname] = 0
endfunction " }}}
function! gita#utils#help#toggle(name) abort " {{{
  let varname = printf('_help_%s_enabled', a:name)
  let b:[varname] = !get(b:, varname, 0)
endfunction " }}}
function! gita#utils#help#get(name) abort " {{{
  if gita#utils#help#is_enabled(a:name)
    return gita#utils#help#read(a:name)
  else
    return []
  endif
endfunction " }}}


let &cpo = s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
