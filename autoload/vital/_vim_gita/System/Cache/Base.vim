"******************************************************************************
" An abstract class of unified cache system
"
" Author:   Alisue <lambdalisue@hashnote.net>
" URL:      http://hashnote.net/
" License:  MIT license
" (C) 2015, Alisue, hashnote.net
"******************************************************************************
let s:save_cpo = &cpo
set cpo&vim

function! s:_vital_loaded(V) dict abort " {{{
  let s:Prelude = a:V.import('Prelude')
  let s:String  = a:V.import('Data.String')
endfunction " }}}
function! s:_vital_depends() abort " {{{
  return ['Prelude', 'Data.String']
endfunction " }}}

function! s:hash(obj) abort " {{{
  let str = s:Prelude.is_string(a:obj) ? a:obj : string(a:obj)
  if strlen(str) < 150
    " hash might be a filename thus.
    let hash = str
    let hash = substitute(hash, ':', '=-', 'g')
    let hash = substitute(hash, '[/\\]', '=+', 'g')
  else
    let hash = s:String.hash(str)
  endif
  return hash
endfunction " }}}

let s:cache = {}
function! s:new() abort " {{{
  return deepcopy(s:cache)
endfunction " }}}
function! s:cache.cache_key(obj) abort " {{{
  return s:hash(a:obj)
endfunction " }}}
function! s:cache.has(name) abort " {{{
  throw "System.Cache.Base: has({name}) is not implemented"
endfunction " }}}
function! s:cache.get(name, ...) abort " {{{
  throw "System.Cache.Base: get({name}[, {default}]) is not implemented"
endfunction " }}}
function! s:cache.set(name, value) abort " {{{
  throw "System.Cache.Base: set({name}, {value}[, {default}]) is not implemented"
endfunction " }}}
function! s:cache.keys() abort " {{{
  throw "System.Cache.Base: keys() is not implemented"
endfunction " }}}
function! s:cache.remove(name) abort " {{{
  throw "System.Cache.Base: remove({name}) is not implemented"
endfunction " }}}
function! s:cache.clear() abort " {{{
  throw "System.Cache.Base: clear() is not implemented"
endfunction " }}}

let &cpo = s:save_cpo
unlet s:save_cpo
"vim: sts=2 sw=2 smarttab et ai textwidth=0 fdm=marker
