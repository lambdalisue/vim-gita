"******************************************************************************
" A fundemental git manipulation library
"
" Author:   Alisue <lambdalisue@hashnote.net>
" URL:      http://hashnote.net/
" License:  MIT license
"
" (C) 2014, Alisue, hashnote.net
"******************************************************************************
let s:save_cpo = &cpo
set cpo&vim

" Vital ======================================================================
let s:config = {}
let s:config.executable = 'git'
let s:config.arguments = ['-c', 'color.ui=false']
let s:config.exec_cwd = '%'
let s:config.exec_cwd_to_worktree_top = 0
let s:config.misc_path = '%'

function! s:_vital_loaded(V) dict abort " {{{
  let s:V = a:V
  let s:Prelude = a:V.import('Prelude')
  let s:Process = a:V.import('Process')
  let s:List = a:V.import('Data.List')
  let s:Path = a:V.import('System.Filepath')

  let self.config = s:config
endfunction " }}}
function! s:_vital_depends() abort " {{{
  return [
        \ 'Prelude',
        \ 'Process',
        \ 'Data.List',
        \ 'System.Filepath',
        \]
endfunction " }}}

function! s:system(args, ...) " {{{
  let args = s:List.flatten(a:args)
  let opts = extend({
        \ 'stdin': '',
        \ 'timeout': 0,
        \ 'cwd': '',
        \}, get(a:000, 0, {}))
  let saved_cwd = ''
  if opts.cwd !=# ''
    let saved_cwd = fnamemodify('.', ':p')
    silent execute 'lcd ' fnameescape(expand(opts.cwd))
  endif

  let original_opts = deepcopy(opts)
  " prevent E677
  if strlen(opts.stdin)
    let opts.input = opts.stdin
  endif
  " remove invalid options for system()
  unlet opts.stdin
  unlet opts.cwd
  let stdout = s:Process.system(args, opts)
  " remove trailing newline
  let stdout = substitute(stdout, '\v%(\r?\n)$', '', '')
  let status = s:Process.get_last_status()
  if saved_cwd !=# ''
    silent execute 'lcd ' fnameescape(saved_cwd)
  endif
  return { 'stdout': stdout, 'status': status, 'args': args, 'opts': original_opts }
endfunction " }}}
function! s:exec(args, ...) " {{{
  let args = [s:config.executable, s:config.arguments, a:args]
  let opts = extend({
        \ 'cwd': s:config.exec_cwd,
        \ 'cwd_to_worktree_top': s:config.exec_cwd_to_worktree_top,
        \ }, get(a:000, 0, {}))
  if opts.cwd_to_worktree_top
    let opts.cwd = s:get_worktree_path(opts.cwd)
  endif
  unlet opts.cwd_to_worktree_top
  " ensure cwd is directory
  let opts.cwd = s:Prelude.path2directory(opts.cwd)
  return s:system(args, opts)
endfunction " }}}
function! s:exec_bool(args, ...) " {{{
  let args = a:args
  let opts = get(a:000, 0, {})
  let result = s:exec(args, opts)
  return result.status == 0 && result.stdout ==# 'true'
endfunction " }}}
function! s:exec_path(args, ...) " {{{
  let args = a:args
  let opts = get(a:000, 0, {})
  let result = s:exec(args, opts)
  if result.status != 0
    return ''
  endif
  return s:Path.remove_last_separator(fnameescape(result.stdout))
endfunction " }}}
function! s:exec_line(args, ...) " {{{
  let args = a:args
  let opts = get(a:000, 0, {})
  let result = s:exec(args, opts)
  if result.status != 0
    return ''
  endif
  return result.stdout
endfunction " }}}

" Fundemental Misc
function! s:detect(...) " {{{
  let path = get(a:000, 0, s:config.misc_path)
  let opts = extend({ 'cwd': path }, get(a:000, 1, {}))
  let opts.cwd_to_worktree_top = 0
  return s:exec_bool(['rev-parse', '--is-inside-work-tree'], opts)
endfunction " }}}
function! s:get_repository_path(...) " {{{
  let path = get(a:000, 0, s:config.misc_path)
  let opts = extend({ 'cwd': path }, get(a:000, 1, {}))
  let opts.cwd_to_worktree_top = 0
  " --git-dir sometime does not return absolute path
  let result = s:exec_path(['rev-parse', '--git-dir'], opts)
  return s:Path.remove_last_separator(fnamemodify(result, ':p'))
endfunction " }}}
function! s:get_worktree_path(...) " {{{
  let path = get(a:000, 0, s:config.misc_path)
  let opts = extend({ 'cwd': path }, get(a:000, 1, {}))
  let opts.cwd_to_worktree_top = 0
  return s:exec_path(['rev-parse', '--show-toplevel'], opts)
endfunction " }}}
function! s:get_relative_path(...) " {{{
  let path = get(a:000, 0, s:config.misc_path)
  let opts = extend({ 'cwd': path }, get(a:000, 1, {}))
  let opts.cwd_to_worktree_top = 0
  let result = s:exec(['rev-parse', '--show-prefix'], opts)
  if result.status != 0
    return ''
  endif
  if isdirectory(path)
    return s:Path.remove_last_separator(fnameescape(result.stdout))
  else
    return s:Path.remove_last_separator(s:Path.join(
          \ fnameescape(result.stdout),
          \ fnamemodify(fnameescape(path), ':t')
          \))
  endif
endfunction " }}}
function! s:get_absolute_path(...) " {{{
  let path = get(a:000, 0, s:config.misc_path)
  let opts = get(a:000, 1, {})
  let opts.cwd_to_worktree_top = 0
  let root = s:get_worktree_path(path, opts)
  return s:Path.remove_last_separator(s:Path.join(root, fnameescape(path)))
endfunction " }}}

" Define Git commands
function! s:_get_SID()
    return matchstr(expand('<sfile>'), '<SNR>\d\+_\ze_get_SID$')
endfunction
function! s:_define_commands() " {{{
  let fnames = [
        \ 'init', 'add', 'rm', 'mv', 'status', 'commit', 'clean',
        \ 'log', 'diff', 'show',
        \ 'branch', 'checkout', 'merge', 'rebase', 'tag',
        \ 'clone', 'fetch', 'pull', 'push', 'remote',
        \ 'reset', 'rebase', 'bisect', 'grep', 'stash', 'prune',
        \ 'rev_parse', 'ls_tree', 'cat_file', 'archive', 'gc',
        \ 'fsck', 'config', 'help',
        \]
  let sid = s:_get_SID()
  for fname in fnames
    " define function dynamically
    let name = substitute(fname, '_', '-', 'g')"
    let exec = join([
          \ printf("function! %s%s(args, ...)", sid, fname),
          \ "  let options = get(a:000, 0, {})",
          \ printf("  return s:exec(['%s', a:args], options)", name),
          \ "endfunction",
          \], "\n")
    execute exec
  endfor
endfunction " }}}
call s:_define_commands()

let &cpo = s:save_cpo
unlet s:save_cpo
"vim: sts=2 sw=2 smarttab et ai textwidth=0 fdm=marker
