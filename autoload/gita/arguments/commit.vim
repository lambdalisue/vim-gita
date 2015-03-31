"******************************************************************************
" vim-gita arguments/commit
"
" Author:   Alisue <lambdalisue@hashnote.net>
" URL:      http://hashnote.net/
" License:  MIT license
" (C) 2015, Alisue, hashnote.net
"******************************************************************************
let s:save_cpo = &cpo
set cpo&vim

let s:Path = gita#util#import('System.Filepath')
let s:ArgumentParser = gita#util#import('ArgumentParser')

function! s:get_parser() abort " {{{
  if !exists('s:parser')
    let s:parser = s:ArgumentParser.new({
          \ 'name': 'Record changes to the repository via Gita interface',
          \})
    call s:parser.add_argument(
          \ '--author',
          \ 'override author for commit', {
          \   'type': 'value',
          \ })
    call s:parser.add_argument(
          \ '--message', '-m',
          \ 'commit message', {
          \   'type': 'value',
          \ })
    call s:parser.add_argument(
          \ '--reedit-message', '-c',
          \ 'reuse and edit message from specified commit', {
          \   'type': 'value',
          \ })
    call s:parser.add_argument(
          \ '--reuse-message', '-C',
          \ 'reuse message from specified commit', {
          \   'type': 'value',
          \ })
    call s:parser.add_argument(
          \ '--all', '-a',
          \ 'commit all changed files', {
          \   'kind': 'switch',
          \ })
    call s:parser.add_argument(
          \ '--include', '-i',
          \ 'add specified files to index for commit', {
          \   'kind': 'value',
          \ })
    call s:parser.add_argument(
          \ '--reset-author',
          \ 'the commit is authored by me now (used with -C/-c/--amend)', {
          \   'kind': 'switch',
          \ })
    call s:parser.add_argument(
          \ '--amend',
          \ 'amend previous commit', {
          \   'kind': 'switch',
          \ })
    call s:parser.add_argument(
          \ '--untracked-files', '-u',
          \ 'show untracked files, optional modes: all, normal, no. (Default: all)', {
          \   'choices': ['all', 'normal', 'no'],
          \   'default': 'all',
          \ })
  endif
  return s:parser
endfunction " }}}

function! gita#arguments#commit#parse(bang, range, ...) abort " {{{
  let cmdline = get(a:000, 0, '')
  let settings = get(a:000, 1, {})
  let parser = s:get_parser()
  let args = [a:bang, a:range, cmdline, settings]
  let opts = call(parser.parse, args, parser)
  return opts
endfunction " }}}
function! gita#arguments#commit#complete(arglead, cmdline, cursorpos) abort " {{{
  let parser = s:get_parser()
  let args = [a:arglead, a:cmdline, a:cursorpos]
  let complete = call(parser.complete, args, parser)
  return complete
endfunction " }}}


let &cpo = s:save_cpo
unlet s:save_cpo
"vim: sts=2 sw=2 smarttab et ai textwidth=0 fdm=marker

