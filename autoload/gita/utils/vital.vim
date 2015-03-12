"******************************************************************************
" vim-gita utility (vital)
"
" Author:   Alisue <lambdalisue@hashnote.net>
" URL:      http://hashnote.net/
" License:  MIT license
" (C) 2015, Alisue, hashnote.net
"******************************************************************************
let s:save_cpo = &cpo
set cpo&vim

let s:V = vital#of('vital')
function! gita#utils#vital#Path() " {{{
  if !exists('s:Path')
    let s:Path = s:V.import('System.Filepath')
  endif
  return s:Path
endfunction " }}}
function! gita#utils#vital#Buffer() " {{{
  if !exists('s:Buffer')
    let s:Buffer = s:V.import('Vim.Buffer')
  endif
  return s:Buffer
endfunction " }}}
function! gita#utils#vital#Git() " {{{
  if !exists('s:Git')
    let s:Git = s:V.import('VCS.Git')
  endif
  return s:Git
endfunction " }}}
function! gita#utils#vital#GitStatusParser() " {{{
  if !exists('s:GitStatusParser')
    let s:GitStatusParser = s:V.import('VCS.Git.StatusParser')
  endif
  return s:GitStatusParser
endfunction " }}}
function! gita#utils#vital#ArgumentParser() " {{{
  if !exists('s:ArgumentParser')
    let s:ArgumentParser = s:V.import('ArgumentParser')
  endif
  return s:ArgumentParser.new()
endfunction " }}}


let &cpo = s:save_cpo
unlet s:save_cpo
"vim: sts=2 sw=2 smarttab et ai textwidth=0 fdm=marker

