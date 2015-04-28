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

let s:Path = gita#util#import('System.Filepath')
let s:ArgumentParser = gita#util#import('ArgumentParser')


function! s:get_parser() abort " {{{
  if !exists('s:parser')
    let s:parser = s:ArgumentParser.new({
          \ 'name': 'An altimate git interface of Vim',
          \})
    call s:parser.add_argument(
          \ 'action',
          \ 'An action of the Gita command', {
          \   'terminal': 1,
          \ })
  endif
  return s:parser
endfunction " }}}


function! gita#argument#parse(bang, range, ...) abort " {{{
  let cmdline = get(a:000, 0, '')
  let parser = s:get_parser()
  let opts = parser.parse(a:bang, a:range, cmdline)

  if opts.__bang__ || !has_key(opts, 'action') || opts.action !~# s:gita_command_names_pattern
    let opts.__name__ = get(opts, 'action', '')
    return opts
  endif

  let parser = call(printf('gita#argument#%s#get_parser', opts.action), [])
  let opts = parser.parse_args(opts.__unknown__, {
        \ '__name__': opts.action,
        \ '__bang__': opts.__bang__,
        \ '__range__': opts.__range__,
        \})
  return opts
endfunction " }}}
function! gita#argument#complete(arglead, cmdline, cursorpos) abort " {{{
  let bang = a:cmdline =~# '\v^Gita!'
  let cmdline = substitute(a:cmdline, '\v^Gita!?\s?', '', '')
  let parser = s:get_parser()
  let opts = parser.parse_cmdline(cmdline)
  if bang || !has_key(opts, 'action') || opts.action !~# s:gita_command_names_pattern
    let candidates = filter(
          \ copy(s:git_command_names),
          \ 'v:val =~# "^" . a:arglead',
          \)
  else
    let parser = call(printf('gita#argument#%s#get_parser', opts.action), [])
    let opts = parser.parse_args(opts.__unknown__, {
          \ '__name__': opts.action,
          \})
    let candidates = call(
          \ parser.complete, [
          \   a:arglead, 
          \   join(opts.__unknown__),
          \   a:cursorpos,
          \   opts,
          \ ],
          \ parser)
  endif
  return candidates
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
      \ 'browse',
      \]
let s:git_command_names_pattern = printf('\v%%(%s)', join(s:git_command_names, '|'))

let s:gita_command_names = [
      \ 'status', 'commit', 'diff', 'browse',
      \]
let s:gita_command_names_pattern = printf('\v%%(%s)', join(s:gita_command_names, '|'))

let &cpo = s:save_cpo
unlet s:save_cpo
"vim: sts=2 sw=2 smarttab et ai textwidth=0 fdm=marker
