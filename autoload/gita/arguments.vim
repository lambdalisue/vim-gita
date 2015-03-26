"******************************************************************************
" vim-gita arguments
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


function! gita#arguments#parse(bang, range, ...) abort " {{{
  let bang = a:bang ==# '!'
  let cmdline = get(a:000, 0, '')
  let args = split(cmdline)
  let name = len(args) ? args[0] : ''
  if !bang && name =~# s:gita_command_names_pattern
    let cmdline = len(args) > 1 ? join(args[1:]) : ''
    let cmdname = printf('gita#arguments#%s#parse', name)
    let opts = call(cmdname, [a:bang, a:range, cmdline])
  else
    let opts = {'args': s:ArgumentParser.shellwords(cmdline)}
  endif
  if !empty(opts)
    " ArgumentParser return empty string for --help
    let opts._name = name
  endif
  return opts
endfunction " }}}
function! gita#arguments#complete(arglead, cmdline, cursorpos) abort " {{{
  let bang = a:cmdline =~# '\v^Gita!'
  let cmdline = substitute(a:cmdline, '\v^Gita!?\s?', '', '')
  let args = split(cmdline)
  let name = len(args) ? args[0] : ''
  if !bang && name =~# s:gita_command_names_pattern
    let cmdline = len(args) > 1 ? join(args[1:]) : ''
    let cmdname = printf('gita#arguments#%s#complete', name)
    let complete = call(cmdname, [a:arglead, cmdline, a:cursorpos])
  else
    let complete = filter(
          \ copy(s:git_command_names),
          \ 'v:val =~# name',
          \)
  endif
  return complete
endfunction
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

let s:gita_command_names = [
      \ 'status', 'commit', 'diff',
      \]
let s:gita_command_names_pattern = printf('\v%%(%s)', join(s:gita_command_names, '|'))

let &cpo = s:save_cpo
unlet s:save_cpo
"vim: sts=2 sw=2 smarttab et ai textwidth=0 fdm=marker
