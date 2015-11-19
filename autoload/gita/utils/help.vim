let s:save_cpoptions = &cpoptions
set cpoptions&vim

" Modules
let s:P = gita#import('System.Filepath')
let s:C = gita#import('System.Cache.Memory')

let s:sfile = expand('<sfile>:p')
let s:cache = s:C.new()

function! s:get_help_directory() abort " {{{
  let repository_root = fnamemodify(s:sfile, ':h:h:h:h')
  return s:P.join(repository_root, 'help')
endfunction " }}}

function! gita#utils#help#is_enabled(name) abort " {{{
  let varname = printf('_gita_help_%s_enabled', a:name)
  return get(b:, varname, 0)
endfunction " }}}
function! gita#utils#help#enable(name) abort " {{{
  let varname = printf('_gita_help_%s_enabled', a:name)
  let b:[varname] = 1
endfunction " }}}
function! gita#utils#help#disable(name) abort " {{{
  let varname = printf('_gita_help_%s_enabled', a:name)
  let b:[varname] = 0
endfunction " }}}
function! gita#utils#help#toggle(name) abort " {{{
  let varname = printf('_gita_help_%s_enabled', a:name)
  let b:[varname] = !get(b:, varname, 0)
endfunction " }}}
function! gita#utils#help#read(name) abort " {{{
  if !s:cache.has(a:name)
    let filename = s:P.join(s:get_help_directory(), a:name . '.txt')
    if !filereadable(filename)
      throw printf(
            \ 'vim-gita: No help file "%s" is found.',
            \ filename,
            \)
    endif
    call s:cache.set(a:name, readfile(filename))
  endif
  return s:cache.get(a:name)
endfunction " }}}
function! gita#utils#help#get(name) abort " {{{
  if gita#utils#help#is_enabled(a:name)
    return gita#utils#help#read(a:name)
  else
    return []
  endif
endfunction " }}}


let &cpoptions = s:save_cpoptions
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
