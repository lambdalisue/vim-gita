"******************************************************************************
" vim-gita argument
"
" Author:   Alisue <lambdalisue@hashnote.net>
" URL:      http://hashnote.net/
" License:  MIT license
" (C) 2015, Alisue, hashnote.net
"******************************************************************************
let s:save_cpo = &cpo
set cpo&vim

" Vital {{{
let s:Path          = gita#util#import('System.Filepath')
let s:ArgumentParser = gita#util#import('ArgumentParser')
" }}}
let s:git_command_names = [
      \ 'init', 'add', 'rm', 'mv', 'status', 'commit', 'clean',
      \ 'log', 'diff', 'show',
      \ 'branch', 'checkout', 'merge', 'rebase', 'tag',
      \ 'clone', 'fetch', 'pull', 'push', 'remote',
      \ 'reset', 'rebase', 'bisect', 'grep', 'stash', 'prune',
      \ 'rev_parse', 'ls_tree', 'cat_file', 'archive', 'gc',
      \ 'fsck', 'config', 'help',
      \]
let s:git_command_names_pattern = printf('\v%%(%s)', join(s:git_command_names, '|'))
function! s:get_command_name(cmdline) " {{{
  let command_name = split(a:cmdline)[0]
  if command_name =~# s:git_command_names_pattern
    return command_name
  else
    return ''
  endif
endfunction " }}}

function! s:get_default_parser() " {{{
  if !exists('s:default_parser')
    let s:default_parser = s:ArgumentParser.new({
          \ 'name': 'Gita',
          \ 'validate_unknown': 0,
          \})
  endif
  return s:default_parser
endfunction " }}}
function! s:get_status_parser() " {{{
  if !exists('s:status_parser')
    let s:status_parser = s:ArgumentParser.new({
          \ 'name': 'Gita status',
          \ 'validate_unknown': 0,
          \})
    call s:status_parser.add_argument(
          \ '--force-construction',
          \ 're-construct the buffer (debug)',
          \)
  endif
  return s:status_parser
endfunction " }}}
function! s:get_commit_parser() " {{{
  if !exists('s:commit_parser')
    let s:commit_parser = s:ArgumentParser.new({
          \ 'name': 'Gita commit',
          \ 'validate_unknown': 0,
          \})
    call s:commit_parser.add_argument(
          \ '--amend',
          \ 'amend previous commit',
          \)
    call s:commit_parser.add_argument(
          \ '--force-construction',
          \ 're-construct the buffer (debug)',
          \)
  endif
  return s:commit_parser
endfunction " }}}
function! s:get_parser(cname) abort " {{{
  let fname = printf('get_%s_parser', a:cname)
  if has_key(s:, fname)
    let fname = 's:' . fname
  else
    let fname = 's:get_default_parser'
  endif
  return call(fname, [])
endfunction " }}}

function! gita#argument#parse(bang, range, ...) abort " {{{
  let cmdline = get(a:000, 0, '')
  let cname = s:get_command_name(cmdline)
  let cmdline = substitute(cmdline, printf('\v^%s', cname), '', '')
  let cparser = s:get_parser(cname)
  let settings = get(a:000, 0, {})
  let options = call(cparser.parse, [a:bang, a:range, cmdline, settings], cparser)
  let options.cname = cname
  return options
endfunction " }}}
function! gita#argument#complete(arglead, cmdline, cursorpos) abort " {{{
  let cname = split(a:cmdline)[0]
  if strlen(cname) == 0 || cname !~# s:git_command_names_pattern
    " filter command names
    let suggestion = filter(
          \ copy(s:git_command_names),
          \ 'v:val =~# cname',
          \)
    return suggestion
  else
    let parser = s:get_parser(cname)
    return call(parser.complete, [a:arglead, a:cmdline, a:cursorpos], parser)
  endif
endfunction
" }}}


let &cpo = s:save_cpo
unlet s:save_cpo
"vim: sts=2 sw=2 smarttab et ai textwidth=0 fdm=marker
