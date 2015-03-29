"******************************************************************************
" vim-gita utility
"
" Author:   Alisue <lambdalisue@hashnote.net>
" URL:      http://hashnote.net/
" License:  MIT license
" (C) 2015, Alisue, hashnote.net
"******************************************************************************
let s:save_cpo = &cpo
set cpo&vim

" Vital {{{
function! s:get_vital() " {{{
  if !exists('s:_vital_module_Vital')
    " TODO replace it to 'vim_gita'
    let s:_vital_module_Vital = vital#of('vital')
  endif
  return s:_vital_module_Vital
endfunction " }}}
function! gita#util#import(name) " {{{
  let cache_name = printf('_vital_module_%s', substitute(a:name, '\.', '_', 'g'))
  if !has_key(s:, cache_name)
    let s:[cache_name] = s:get_vital().import(a:name)
  endif
  return s:[cache_name]
endfunction " }}}
let s:Prelude = gita#util#import('Prelude')
let s:List    = gita#util#import('Data.List')
" }}}

" Vital
function! gita#util#is_numeric(...) " {{{
  return call(s:Prelude.is_numeric, a:000, s:Prelude)
endfunction " }}}
function! gita#util#is_number(...) " {{{
  return call(s:Prelude.is_number, a:000, s:Prelude)
endfunction " }}}
function! gita#util#is_float(...) " {{{
  return call(s:Prelude.is_float, a:000, s:Prelude)
endfunction " }}}
function! gita#util#is_string(...) " {{{
  return call(s:Prelude.is_string, a:000, s:Prelude)
endfunction " }}}
function! gita#util#is_funcref(...) " {{{
  return call(s:Prelude.is_funcref, a:000, s:Prelude)
endfunction " }}}
function! gita#util#is_list(...) " {{{
  return call(s:Prelude.is_list, a:000, s:Prelude)
endfunction " }}}
function! gita#util#is_dict(...) " {{{
  return call(s:Prelude.is_dict, a:000, s:Prelude)
endfunction " }}}
function! gita#util#flatten(...) " {{{
  return call(s:List.flatten, a:000, s:List)
endfunction " }}}
function! gita#util#listalize(val) abort " {{{
  return gita#util#is_list(a:val) ? a:val : [a:val]
endfunction " }}}

" Message
function! gita#util#echo(hl, msg) abort " {{{
  execute 'echohl' a:hl
  try
    for m in split(a:msg, '\v\r?\n')
      echo m
    endfor
  finally
    echohl None
  endtry
endfunction " }}}
function! gita#util#echomsg(hl, msg) abort " {{{
  execute 'echohl' a:hl
  try
    for m in split(a:msg, '\v\r?\n')
      echomsg m
    endfor
  finally
    echohl None
  endtry
endfunction " }}}
function! gita#util#input(hl, msg, ...) abort " {{{
  execute 'echohl' a:hl
  try
    return input(a:msg, get(a:000, 0, ''))
  finally
    echohl None
  endtry
endfunction " }}}
function! gita#util#debug(...) abort " {{{
  if !get(g:, 'gita#debug', 0)
    return
  endif
  let parts = []
  for x in a:000
    call add(parts, string(x))
    silent unlet! x
  endfor
  call gita#util#echomsg('Comment', 'DEBUG: ' . join(parts))
endfunction " }}}
function! gita#util#info(message, ...) abort " {{{
  let title = get(a:000, 0, '')
  if strlen(title)
    call gita#util#echomsg('Title', title)
    call gita#util#echomsg('None', a:message)
  else
    call gita#util#echomsg('Title', a:message)
  endif
endfunction " }}}
function! gita#util#warn(message, ...) abort " {{{
  let title = get(a:000, 0, '')
  if strlen(title)
    call gita#util#echomsg('WarningMsg', title)
    call gita#util#echomsg('None', a:message)
  else
    call gita#util#echomsg('WarningMsg', a:message)
  endif
endfunction " }}}
function! gita#util#error(message, ...) abort " {{{
  let title = get(a:000, 0, '')
  if strlen(title)
    call gita#util#echomsg('Error', title)
    call gita#util#echomsg('None', a:message)
  else
    call gita#util#echomsg('Error', a:message)
  endif
endfunction " }}}
function! gita#util#ask(message, ...) abort " {{{
  let result = gita#util#input('Question', a:message, get(a:000, 0, ''))
  redraw
  return result
endfunction " }}}
function! gita#util#asktf(message, ...) abort " {{{
  let result = gita#util#ask(
        \ printf('%s [yes/no]: ', a:message),
        \ get(a:000, 0, ''))
  while result !~? '^\%(y\%[es]\|n\%[o]\)$'
    redraw
    if result == ''
      call gita#util#warn('Canceled.')
      break
    endif
    call gita#util#error('Invalid input.')
    let result = gita#util#ask(printf('%s [yes/no]: ', a:message))
  endwhile
  redraw
  return result =~? 'y\%[es]'
endfunction " }}}

" Buffer
function! gita#util#buffer_open(buffer, ...) abort " {{{
  let B = gita#util#import('Vim.Buffer')
  let opener = get(a:000, 0, get(g:, 'gita#buffer#opener', 'edit'))
  return B.open(a:buffer, opener)
endfunction " }}}
function! gita#util#buffer_update(buflines) abort " {{{
  let saved_cur = getpos('.')
  let saved_undolevels = &undolevels
  setlocal undolevels=-1
  silent %delete _
  call setline(1, a:buflines)
  call setpos('.', saved_cur)
  silent execute 'setlocal undolevels=' . saved_undolevels
  setlocal nomodified
endfunction " }}}
function! gita#util#buffer_clear_undo() abort " {{{
  let saved_undolevels = &undolevels
  setlocal undolevels=-1
  silent execute "normal a \<BS>\<ESC>"
  silent execute 'setlocal undolevels=' . saved_undolevels
endfunction " }}}

" Window
function! gita#util#choosewin() abort " {{{
  let winnum  = winnr()
  let winnums = filter(range(1, winnr('$')), '!s:choosewin_is_ignored(v:val)')
  let options = {
        \ 'auto_choose': 1,
        \}
  try
    let choice = choosewin#start(winnums, options)
    if !empty(choice)
      let [tabnum, winnum] = choice
      execute 'tabnext' tabnum
      return winnum
    endif
  catch
    call gita#util#warn(
          \ 'An opener "select" require "t9md/choosewin" to be installed.'
          \ 'Dependencies are not installed.',
          \)
    return -1
  endtry
endfunction
function! s:choosewin_is_ignored(winnum) abort
  let ignored_filetypes = [
        \ 'gita-status', 'gita-commit', 'gista-list',
        \ 'unite', 'vimfiler', 'vimshell', 'nerdtree',
        \ 'gundo', 'tagbar',
        \]
  return index(ignored_filetypes, getbufvar(winbufnr(a:winnum), '&filetype')) != -1
endfunction " }}}

" Invoker
function! gita#util#invoker_get(...) abort " {{{
  let bufname = get(a:000, 0, '%')
  let invoker = getbufvar(bufname, '_invoker', {})
  if empty(invoker)
    let bufnum = bufnr(bufname)
    let winnum = bufwinnr(bufnum)
    let invoker = {
          \ 'bufnum': bufnum,
          \ 'winnum': winnum,
          \}
  endif
  return invoker
endfunction " }}}
function! gita#util#invoker_set(invoker, ...) abort " {{{
  let bufname = get(a:000, 0, '%')
  call setbufvar(bufname, '_invoker', a:invoker)
endfunction " }}}
function! gita#util#invoker_get_winnum(...) abort " {{{
  let invoker = call('gita#util#invoker_get', a:000)
  let bufnum = invoker.bufnum
  let winnum = bufwinnr(bufnum)
  if winnum == -1
    let winnum = invoker.winnum
  endif
  return winnum
endfunction " }}}
function! gita#util#invoker_focus(...) abort " {{{
  let winnum = call('gita#util#invoker_get_winnum', a:000)
  if winnum <= winnr('$')
    silent execute winnum . 'wincmd w'
  else
    silent execute 'wincmd p'
  endif
endfunction " }}}

" Interface
function! gita#util#interface_open(name) abort " {{{
  if !exists('s:interface_buffer_manager')
    let BM = gita#util#import('Vim.BufferManager')
    let s:interface_buffer_manager = BM.new({
          \   'opener': 'topleft 20 split',
          \   'range': 'tabpage',
          \})
  endif
  return s:interface_buffer_manager.open(a:name, get(a:000, 0, {}))
endfunction " }}}
function! gita#util#interface_get_misc_lines() abort " {{{
  let gita = gita#get()
  let meta = gita.git.get_meta()
  let name = fnamemodify(gita.git.worktree, ':t')
  let branch = meta.current_branch
  let remote_name = meta.current_branch_remote
  let remote_branch = meta.current_remote_branch
  let outgoing = gita.git.count_commits_ahead_of_remote()
  let incoming = gita.git.count_commits_behind_remote()
  let is_connected = !(empty(remote_name) || empty(remote_branch))

  let lines = []
  if is_connected
    call add(lines,
          \ printf('# Index and working tree status on a branch `%s/%s` <> `%s/%s`',
          \   name, branch, remote_name, remote_branch
          \))
    if outgoing > 0 && incoming > 0
      call add(lines,
            \ printf('# The branch is %d commit(s) ahead and %d commit(s) behind of `%s/%s`',
            \   outgoing, incoming, remote_name, remote_branch,
            \))
    elseif outgoing > 0
      call add(lines,
            \ printf('# The branch is %d commit(s) ahead of `%s/%s`',
            \   outgoing, remote_name, remote_branch,
            \))
    elseif incoming > 0
      call add(lines,
            \ printf('# The branch is %d commit(s) behind `%s/%s`',
            \   incoming, remote_name, remote_branch,
            \))
    endif
  else
    call add(lines,
          \ printf('# Index and working tree status on a branch `%s/%s`',
          \   name, branch
          \))

  endif
  return lines
endfunction " }}}

" Autocmd
function! gita#util#doautocmd(name) abort " {{{
  let name = printf('vim-gita-%s', a:name)
  if 703 < v:version || (v:version == 703 && has('patch438'))
    silent execute 'doautocmd <nomodeline> User ' . name
  else
    silent execute 'doautocmd User ' . name
  endif
endfunction " }}}

let &cpo = s:save_cpo
unlet s:save_cpo
"vim: sts=2 sw=2 smarttab et ai textwidth=0 fdm=marker

