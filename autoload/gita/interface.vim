"******************************************************************************
" vim-gita interface
"
" Author:   Alisue <lambdalisue@hashnote.net>
" URL:      http://hashnote.net/
" License:  MIT license
" (C) 2015, Alisue, hashnote.net
"******************************************************************************
let s:save_cpo = &cpo
set cpo&vim

" Vital modules ==============================================================
" {{{
let s:Path          = gita#util#import('System.Filepath')
let s:Buffer        = gita#util#import('Vim.Buffer')
let s:BufferManager = gita#util#import('Vim.BufferManager')
let s:Cache         = gita#util#import('System.Cache.Simple')
let s:Git           = gita#util#import('VCS.Git')
let s:GitMisc       = gita#util#import('VCS.Git.Misc')
" }}}

" Private=====================================================================
function! s:get_buffer_manager() abort " {{{
  if !exists('s:buffer_manager')
    let config = {
          \ 'opener': 'topleft 20 split',
          \ 'range': 'tabpage',
          \}
    let s:buffer_manager = s:BufferManager.new(config)
  endif
  return s:buffer_manager
endfunction " }}}
function! s:get_header_lines(path) abort " {{{
  let b = substitute(s:GitMisc.get_local_branch_name(a:path), '\v^"|"$', '', 'g')
  let r = substitute(s:GitMisc.get_remote_branch_name(a:path), '\v^"|"$', '', 'g')
  let o = s:GitMisc.count_commits_ahead_of_remote(a:path)
  let i = s:GitMisc.count_commits_behind_remote(a:path)

  let buflines = []
  if strlen(r) > 0
    call add(buflines, printf('# On branch %s -> %s', b, r))
  else
    call add(buflines, printf('# On branch %s', b))
  endif
  if o > 0 && i > 0
    call add(buflines, printf(
          \ '# This branch is %d commit(s) ahead of and %d commit(s) behind %s',
          \ o, i, r
          \))
  elseif o > 0
    call add(buflines, printf(
          \ '# This branch is %d commit(s) ahead of %s',
          \ o, r
          \))
  elseif i > 0
    call add(buflines, printf(
          \ '# This branch is %d commit(s) behind %s',
          \ i, r
          \))
  endif
  return buflines
endfunction " }}}
function! s:get_status_line(status) abort " {{{
  return a:status.record
endfunction " }}}
function! s:eliminate_comment_lines(lines) abort " {{{
  return filter(copy(a:lines), 'v:val !~# "^#"')
endfunction " }}}
function! s:throw_exception_except_on_valid_filetype(...) abort " {{{
  let fname = get(a:000, 0, 'function')
  if &filetype != s:const.status_filetype && &filetype != s:const.commit_filetype
    throw printf('vim-gita: %s required to be executed on a proper filetype buffer', fname)
  endif
endfunction " }}}
function! s:throw_exception_except_on_status_filetype(...) abort " {{{
  let fname = get(a:000, 0, 'function')
  if &filetype != s:const.status_filetype
    throw printf('vim-gita: %s required to be executed on a gita-status filetype buffer', fname)
  endif
endfunction " }}}
function! s:throw_exception_except_on_commit_filetype(...) abort " {{{
  let fname = get(a:000, 0, 'function')
  if &filetype != s:const.commit_filetype
    throw printf('vim-gita: %s required to be executed on a gita-commit filetype buffer', fname)
  endif
endfunction " }}}

" selected status
function! s:get_selected_status() abort " {{{
  call s:throw_exception_except_on_valid_filetype('s:get_selected_status')
  let statuses_map = b:gita.get('statuses_map', {})
  let selected_line = getline('.')
  return get(statuses_map, selected_line, {})
endfunction " }}}
function! s:get_selected_statuses() abort " {{{
  call s:throw_exception_except_on_valid_filetype('s:get_selected_status')
  let statuses_map = b:gita.get('statuses_map', {})
  let selected_lines = getline(getpos("'<")[1], getpos("'>")[1])
  let selected_statuses = []
  for selected_line in selected_lines
    let status = get(statuses_map, selected_line, {})
    if !empty(status)
      call add(selected_statuses, status)
    endif
  endfor
  return selected_statuses
endfunction " }}}

" invoker
function! s:invoker_focus(gita) abort " {{{
  let winnum = a:gita.get('invoker_winnum', -1)
  if winnum <= winnr('$')
    silent execute winnum . 'wincmd w'
  else
    silent execute 'wincmd p'
  endif
endfunction " }}}
function! s:invoker_get_bufnum(gita) abort " {{{
  let bufnum = a:gita.get('invoker_bufnum', -1)
  if bufwinnr(bufnum) == -1
    " invoker is closed. use a nearest buffer num
    let winnum = a:gita.get('invoker_winnum', -1)
    let bufnum = winnum <= winnr('$') ? winbufnr(winnum) : -1
  endif
  return bufnum
endfunction " }}}
function! s:invoker_get_winnum(gita) abort " {{{
  let bufnum = a:gita.get('invoker_bufnum', -1)
  let winnum = bufwinnr(bufnum)
  if winnum == -1
    " invoker is closed. use a nearest window num
    let winnum = a:gita.get('invoker_winnum', -1)
  endif
  " return -1 if the winnum is invalid
  return winnum <= winnr('$') ? winnum : -1
endfunction " }}}

" mapping
function! s:smart_map(lhs, rhs) abort " {{{
  " return {rhs} if the mapping is called on Git status line of status/commit
  " buffer. otherwise it return {lhs}
  call s:throw_exception_except_on_valid_filetype('s:smart_map')
  let selected_status = s:get_selected_status()
  return empty(selected_status) ? a:lhs : a:rhs
endfunction " }}}
function! s:define_mappings() abort " {{{
  call s:throw_exception_except_on_valid_filetype('s:define_mappings')

  nnoremap <silent><buffer> <Plug>(gita-action-commit)              :<C-u>call <SID>monoaction('commit')<CR>
  nnoremap <silent><buffer> <Plug>(gita-action-status-open)         :<C-u>call <SID>monoaction('status_open')<CR>
  nnoremap <silent><buffer> <Plug>(gita-action-status-update)       :<C-u>call <SID>monoaction('status_update')<CR>
  nnoremap <silent><buffer> <Plug>(gita-action-commit-open)         :<C-u>call <SID>monoaction('commit_open')<CR>
  nnoremap <silent><buffer> <Plug>(gita-action-commit-open-amend)   :<C-u>call <SID>monoaction('commit_open', { 'amend': 1, 'force_construction': 1 })<CR>
  nnoremap <silent><buffer> <Plug>(gita-action-commit-open-noamend) :<C-u>call <SID>monoaction('commit_open', { 'amend': 0, 'force_construction': 1 })<CR>
  nnoremap <silent><buffer> <Plug>(gita-action-commit-update)       :<C-u>call <SID>monoaction('commit_update')<CR>

  nnoremap <silent><buffer> <Plug>(gita-action-add)         :<C-u>call <SID>monoaction('add')<CR>
  nnoremap <silent><buffer> <Plug>(gita-action-ADD)         :<C-u>call <SID>monoaction('add', { 'force': 1 })<CR>
  nnoremap <silent><buffer> <Plug>(gita-action-rm)          :<C-u>call <SID>monoaction('rm')<CR>
  nnoremap <silent><buffer> <Plug>(gita-action-RM)          :<C-u>call <SID>monoaction('rm', { 'force': 1 })<CR>
  nnoremap <silent><buffer> <Plug>(gita-action-rm-cached)   :<C-u>call <SID>monoaction('rm_cached')<CR>
  nnoremap <silent><buffer> <Plug>(gita-action-checkout)    :<C-u>call <SID>monoaction('checkout')<CR>
  nnoremap <silent><buffer> <Plug>(gita-action-CHECKOUT)    :<C-u>call <SID>monoaction('checkout', { 'force': 1 })<CR>
  nnoremap <silent><buffer> <Plug>(gita-action-revert)      :<C-u>call <SID>monoaction('revert')<CR>
  nnoremap <silent><buffer> <Plug>(gita-action-toggle)      :<C-u>call <SID>monoaction('toggle')<CR>
  nnoremap <silent><buffer> <Plug>(gita-action-diff-split)  :<C-u>call <SID>monoaction('diff', { 'opener': 'split' })<CR>
  nnoremap <silent><buffer> <Plug>(gita-action-diff-vsplit) :<C-u>call <SID>monoaction('diff', { 'opener': 'vsplit' })<CR>
  nnoremap <silent><buffer> <Plug>(gita-action-open-edit)   :<C-u>call <SID>monoaction('open', { 'opener': 'edit' })<CR>
  nnoremap <silent><buffer> <Plug>(gita-action-open-split)  :<C-u>call <SID>monoaction('open', { 'opener': 'split' })<CR>
  nnoremap <silent><buffer> <Plug>(gita-action-open-vsplit) :<C-u>call <SID>monoaction('open', { 'opener': 'vsplit' })<CR>
  nnoremap <silent><buffer> <Plug>(gita-action-open-left)   :<C-u>call <SID>monoaction('open', { 'opener': 'left' })<CR>
  nnoremap <silent><buffer> <Plug>(gita-action-open-right)  :<C-u>call <SID>monoaction('open', { 'opener': 'right' })<CR>
  nnoremap <silent><buffer> <Plug>(gita-action-open-above)  :<C-u>call <SID>monoaction('open', { 'opener': 'above' })<CR>
  nnoremap <silent><buffer> <Plug>(gita-action-open-below)  :<C-u>call <SID>monoaction('open', { 'opener': 'below' })<CR>
  nnoremap <silent><buffer> <Plug>(gita-action-open-tabnew) :<C-u>call <SID>monoaction('open', { 'opener': 'tabnew' })<CR>

  vnoremap <silent><buffer> <Plug>(gita-action-add)         :<C-u>call <SID>multiaction('add')<CR>
  vnoremap <silent><buffer> <Plug>(gita-action-ADD)         :<C-u>call <SID>multiaction('add', { 'force': 1 })<CR>
  vnoremap <silent><buffer> <Plug>(gita-action-rm)          :<C-u>call <SID>multiaction('rm')<CR>
  vnoremap <silent><buffer> <Plug>(gita-action-RM)          :<C-u>call <SID>multiaction('rm', { 'force': 1 })<CR>
  vnoremap <silent><buffer> <Plug>(gita-action-rm-cached)   :<C-u>call <SID>multiaction('rm_cached')<CR>
  vnoremap <silent><buffer> <Plug>(gita-action-checkout)    :<C-u>call <SID>multiaction('checkout')<CR>
  vnoremap <silent><buffer> <Plug>(gita-action-CHECKOUT)    :<C-u>call <SID>multiaction('checkout', { 'force': 1 })<CR>
  vnoremap <silent><buffer> <Plug>(gita-action-revert)      :<C-u>call <SID>multiaction('revert')<CR>
  vnoremap <silent><buffer> <Plug>(gita-action-toggle)      :<C-u>call <SID>multiaction('toggle')<CR>
  vnoremap <silent><buffer> <Plug>(gita-action-diff-split)  :<C-u>call <SID>multiaction('diff', { 'opener': 'split' })<CR>
  vnoremap <silent><buffer> <Plug>(gita-action-diff-vsplit) :<C-u>call <SID>multiaction('diff', { 'opener': 'vsplit' })<CR>
  vnoremap <silent><buffer> <Plug>(gita-action-open-edit)   :<C-u>call <SID>multiaction('open', { 'opener': 'edit' })<CR>
  vnoremap <silent><buffer> <Plug>(gita-action-open-split)  :<C-u>call <SID>multiaction('open', { 'opener': 'split' })<CR>
  vnoremap <silent><buffer> <Plug>(gita-action-open-vsplit) :<C-u>call <SID>multiaction('open', { 'opener': 'vsplit' })<CR>
  vnoremap <silent><buffer> <Plug>(gita-action-open-left)   :<C-u>call <SID>multiaction('open', { 'opener': 'left' })<CR>
  vnoremap <silent><buffer> <Plug>(gita-action-open-right)  :<C-u>call <SID>multiaction('open', { 'opener': 'right' })<CR>
  vnoremap <silent><buffer> <Plug>(gita-action-open-above)  :<C-u>call <SID>multiaction('open', { 'opener': 'above' })<CR>
  vnoremap <silent><buffer> <Plug>(gita-action-open-below)  :<C-u>call <SID>multiaction('open', { 'opener': 'below' })<CR>
  vnoremap <silent><buffer> <Plug>(gita-action-open-tabnew) :<C-u>call <SID>multiaction('open', { 'opener': 'tabnew' })<CR>

  if get(g:, 'gita#interface#enable_default_keymaps', 1)
    nmap <buffer>       q      :<C-u>q<CR>
    nmap <buffer><expr> <CR>   <SID>smart_map('<CR>',   '<Plug>(gita-action-open-edit)')
    nmap <buffer><expr> <S-CR> <SID>smart_map('<S-CR>', '<Plug>(gita-action-diff-vsplit)')
    nmap <buffer><expr> e      <SID>smart_map('e',      '<Plug>(gita-action-open-edit)')
    nmap <buffer><expr> E      <SID>smart_map('E',      '<Plug>(gita-action-open-vsplit)')
    nmap <buffer><expr> <C-e>  <SID>smart_map('<C-e>',  '<Plug>(gita-action-open-split)')
    nmap <buffer><expr> d      <SID>smart_map('d',      '<Plug>(gita-action-diff-split)')
    nmap <buffer><expr> D      <SID>smart_map('D',      '<Plug>(gita-action-diff-vsplit)')
    nmap <buffer><expr> <C-d>  <SID>smart_map('<C-d>',  '<Plug>(gita-action-diff-split)')

    if &filetype == s:const.status_filetype
      nmap <buffer>       <C-l>  <Plug>(gita-action-status-update)
      nmap <buffer>       cc     <Plug>(gita-action-commit-open)
      nmap <buffer>       cA     <Plug>(gita-action-commit-open-amend)
      nmap <buffer>       cC     <Plug>(gita-action-commit-open-noamend)
      nmap <buffer><expr> -a     <SID>smart_map('-a',     '<Plug>(gita-action-add)')
      nmap <buffer><expr> -A     <SID>smart_map('-A',     '<Plug>(gita-action-ADD)')
      nmap <buffer><expr> -r     <SID>smart_map('-r',     '<Plug>(gita-action-rm)')
      nmap <buffer><expr> -R     <SID>smart_map('-R',     '<Plug>(gita-action-RM)')
      nmap <buffer><expr> -h     <SID>smart_map('-h',     '<Plug>(gita-action-rm-cached)')
      nmap <buffer><expr> -c     <SID>smart_map('-c',     '<Plug>(gita-action-checkout)')
      nmap <buffer><expr> -C     <SID>smart_map('-C',     '<Plug>(gita-action-CHECKOUT)')
      nmap <buffer><expr> -=     <SID>smart_map('-=',     '<Plug>(gita-action-revert)')
      nmap <buffer><expr> --     <SID>smart_map('--',     '<Plug>(gita-action-toggle)')

      vmap <buffer><expr> -a     <SID>smart_map('-a', '<Plug>(gita-action-add)')
      vmap <buffer><expr> -A     <SID>smart_map('-A', '<Plug>(gita-action-ADD)')
      vmap <buffer><expr> -r     <SID>smart_map('-r', '<Plug>(gita-action-rm)')
      vmap <buffer><expr> -R     <SID>smart_map('-R', '<Plug>(gita-action-RM)')
      vmap <buffer><expr> -h     <SID>smart_map('-h', '<Plug>(gita-action-rm-cached)')
      vmap <buffer><expr> -c     <SID>smart_map('-c', '<Plug>(gita-action-checkout)')
      vmap <buffer><expr> -C     <SID>smart_map('-C', '<Plug>(gita-action-CHECKOUT)')
      vmap <buffer><expr> -=     <SID>smart_map('-=', '<Plug>(gita-action-revert)')
      vmap <buffer><expr> --     <SID>smart_map('--', '<Plug>(gita-action-toggle)')
    else
      nmap <buffer>       <C-l>  <Plug>(gita-action-commit-update)
      nmap <buffer>       cc     <Plug>(gita-action-status-open)
      nmap <buffer>       CC     <Plug>(gita-action-commit)
    endif
  endif
endfunction " }}}

" actions
function! s:action(name, ...) abort " {{{
  call s:throw_exception_except_on_valid_filetype('s:action')
  let options = extend({
        \ 'multiple': 0,
        \ 'worktree_path': b:gita.get('worktree_path'),
        \}, get(a:000, 0, {}))
  if options.multiple
    let selected_statuses = s:get_selected_statuses()
  else
    let selected_statuses = [ s:get_selected_status() ]
  endif
  if empty(selected_statuses) && a:name !~# s:statuses_optional_actions_pattern
    return
  endif
  return call(printf('s:action_%s', a:name), [selected_statuses, options])
endfunction
let s:statuses_optional_actions = [
      \ 'switch_to_status',
      \ 'switch_to_commit',
      \ 'update_status',
      \ 'update_commit',
      \ 'commit',
      \]
let s:statuses_optional_actions_pattern =
      \ printf('\v%%(%s)', join(s:statuses_optional_actions, '|'))
" }}}
function! s:monoaction(name, ...) abort " {{{
  let options = get(a:000, 0, {})
  let options.multiple = 0
  return s:action(a:name, options)
endfunction " }}}
function! s:multiaction(name, ...) abort " {{{
  let options = get(a:000, 0, {})
  let options.multiple = 1
  return s:action(a:name, options)
endfunction " }}}
function! s:action_status_open(statuses, options) abort " {{{
  if &modified && !get(a:options, 'force', 0)
    call gita#util#warn(
          \ 'the modification on the buffer has not saved yet.'
          \)
    return
  endif
  call s:status_open(a:options)
endfunction " }}}
function! s:action_status_update(statuses, options) abort " {{{
  call s:status_update()
  redraw!
endfunction " }}}
function! s:action_commit_open(statuses, options) abort " {{{
  if &modified && !get(a:options, 'force', 0)
    call gita#util#warn(
          \ 'the modification on the buffer has not saved yet. save the buffer with ":w"',
          \)
    return
  endif
  call s:commit_open(a:options)
endfunction " }}}
function! s:action_commit_update(statuses, options) abort " {{{
  call s:commit_update()
  redraw!
endfunction " }}}
function! s:action_add(statuses, options) abort " {{{
  let options = extend({ 'force': 0 }, a:options)
  " eliminate invalid statuses
  let valid_status_paths = []
  for status in a:statuses
    if status.is_ignored && !force
      call gita#util#warn(printf(
            \ 'ignored file "%s" could not be added. use <Plug>(gita-action-ADD) to add',
            \ status.path)
            \)
      continue
    elseif !status.is_unstaged && !status.is_untracked
      call gita#util#debug(printf(
            \ 'no changes are existing on the file "%s" (working tree is clean)',
            \ status.path)
            \)
      continue
    endif
    call add(valid_status_paths, status.path)
  endfor
  if empty(valid_status_paths)
    call gita#util#warn('no valid file was selected. cancel the operation.')
    return
  endif
  " execute Git command
  let fargs = options.force ? ['--force', '--'] : ['--']
  let fargs = fargs + valid_status_paths
  let result = s:Git.add(fargs, { 'cwd': options.worktree_path })
  if result.status == 0
    call gita#util#info(result.stdout)
    call s:status_update()
  else
    call gita#util#error(result.stdout, 'An exception has occured')
  endif
endfunction " }}}
function! s:action_rm(statuses, options) abort " {{{
  let options = extend({ 'force': 0 }, a:options)
  " eliminate invalid statuses
  let valid_status_paths = []
  for status in a:statuses
    if status.is_ignored && !force
      " TODO is this behavor correct?
      call gita#util#warn(printf(
            \ 'ignored file "%s" could not be removed. use <Plug>(gita-action-RM) to remove',
            \ status.path)
            \)
      continue
    elseif !status.is_unstaged
      call gita#util#debug(printf(
            \ 'no changes are existing on the file "%s" (working tree is clean)',
            \ status.path)
            \)
      continue
    endif
    call add(valid_status_paths, status.path)
  endfor
  if empty(valid_status_paths)
    call gita#util#warn('no valid file was selected. cancel the operation.')
    return
  endif
  " execute Git command
  let fargs = options.force ? ['--force', '--'] : ['--']
  let fargs = fargs + valid_status_paths
  let result = s:Git.rm(fargs, { 'cwd': options.worktree_path })
  if result.status == 0
    call gita#util#info(result.stdout)
    call s:status_update()
  else
    call gita#util#error(result.stdout, 'An exception has occured')
  endif
endfunction " }}}
function! s:action_rm_cached(statuses, options) abort " {{{
  " eliminate invalid statuses
  let valid_status_paths = []
  for status in a:statuses
    if !status.is_staged
      call gita#util#debug(printf(
            \ 'no changes are existing on the index "%s" (index is clean)',
            \ status.path)
            \)
      continue
    endif
    call add(valid_status_paths, status.path)
  endfor
  if empty(valid_status_paths)
    call gita#util#warn('no valid file was selected. cancel the operation.')
    return
  endif
  " execute Git command
  let fargs = ['--cached', '--']
  let fargs = fargs + valid_status_paths
  let result = s:Git.rm(fargs, { 'cwd': options.worktree_path })
  if result.status == 0
    call gita#util#info(result.stdout)
    call s:status_update()
  else
    call gita#util#error(result.stdout, 'An exception has occured')
  endif
endfunction " }}}
function! s:action_checkout(statuses, options) abort " {{{
  let options = extend({ 'force': 0 }, a:options)
  " eliminate invalid statuses
  let valid_status_paths = []
  for status in a:statuses
    if status.is_conflicted
      call gita#util#error(printf(
            \ 'the behavior of checking out a conflicted file "%s" is not defined.',
            \ status.path)
            \)
      continue
    elseif status.is_ignored
      call gita#util#error(printf(
            \ 'the behavior of checking out an ignored file "%s" is not defined.',
            \ status.path)
            \)
      continue
    elseif status.is_unstaged && !force
      call gita#util#warn(printf(
            \ 'locally changed file "%s" could not be checked out. use <Plug>(gita-action-CHECKOUT) to checkout',
            \ status.path)
            \)
      continue
    endif
    call add(valid_status_paths, status.path)
  endfor
  if empty(valid_status_paths)
    call gita#util#warn('no valid file was selected. cancel the operation.')
    return
  endif
  " execute Git command
  let fargs = options.force ? ['--force', 'HEAD', '--'] : ['HEAD', '--']
  let fargs = fargs + valid_status_paths
  let result = s:Git.checkout(fargs, { 'cwd': options.worktree_path })
  if result.status == 0
    call gita#util#info(result.stdout)
    call s:status_update()
  else
    call gita#util#error(result.stdout, 'An exception has occured')
  endif
endfunction " }}}
function! s:action_revert(statuses, options) abort " {{{
  " eliminate invalid statuses
  let valid_statuses = []
  for status in a:statuses
    if status.is_conflicted
      call gita#util#error(printf(
            \ 'the behavior of reverting a conflicted file "%s" is not defined.',
            \ status.path)
            \)
      continue
    elseif status.is_ignored
      call gita#util#error(printf(
            \ 'the behavior of reverting an ignored file "%s" is not defined.',
            \ status.path)
            \)
      continue
    endif
    call add(valid_statuses, status)
  endfor
  if empty(valid_statuses)
    call gita#util#warn('no valid file was selected. cancel the operation.')
    return
  endif

  " remove untracked file or checkout HEAD file to discard the local changes
  for status in valid_statuses
    if status.is_untracked
      call gita#util#warn(
            \ 'This operation will remove the untracked file and could not be reverted',
            \ 'CAUTION: The operation could not be reverted',
            \)
      let a = gita#util#asktf('Are you sure that you want to remove the untracked file?')
      if a
        let abspath = s:Git.get_absolute_path(status.path, { 'cwd': options.worktree_path })
        call delete(abspath)
      endif
    else
      call gita#util#warn(
            \ 'This operation will discard the local changes on the file and could not be reverted',
            \ 'CAUTION: The operation could not be reverted',
            \)
      let a = gita#util#asktf('Are you sure that you want to discard the local changes on the file?')
      if a
        call s:action_checkout(status, 'force')
      endif
    endif
  endfor
endfunction " }}}
function! s:action_toggle(statuses, options) abort " {{{
  " classify statuses
  let add_statuses = []
  let rm_statuses = []
  let rm_cached_statuses = []
  for status in a:statuses
    if status.is_conflicted
      call gita#util#error(printf(
            \ 'the behavior of toggling a conflicted file "%s" is not defined.',
            \ status.path)
            \)
      continue
    elseif status.is_ignored
      call gita#util#error(printf(
            \ 'the behavior of toggling an ignored file "%s" is not defined.',
            \ status.path)
            \)
      continue
    endif
    if status.is_unstaged
      if status.worktree == 'D'
        call add(rm_statuses, status)
      else
        call add(add_statuses, status)
      endif
    elseif status.is_untracked
        call add(add_statuses, status)
    else
        call add(rm_cached_statuses, status)
    endif
  endfor
  if empty(add_statuses) && empty(rm_statuses) && empty(rm_cached_statuses)
    call gita#util#warn('no valid file was selected. cancel the operation.')
    return
  endif
  if !empty(add_statuses)
    call s:action_add(add_statuses, a:options)
  endif
  if !empty(rm_statuses)
    call s:action_rm(rm_statuses, a:options)
  endif
  if !empty(rm_cached_statuses)
    call s:action_rm_cached(rm_cached_statuses, a:options)
  endif
endfunction " }}}
function! s:action_open(statuses, options) abort " {{{
  let options = extend({ 'opener': 'edit' }, a:options)
  let opener = get(g:gita#interface#opener_aliases, options.opener, options.opener)
  let invoker_winnum = s:invoker_get_winnum(b:gita)
  if invoker_winnum != -1
    silent execute invoker_winnum . 'wincmd w'
  else
    silent execute 'wincmd p'
  endif
  " open the selected status files
  for status in a:statuses
    let path = get(status, 'path2', status.path)
    call s:Buffer.open(path, opener)
  endfor
endfunction " }}}
function! s:action_diff(statuses, options) abort " {{{
  call gita#util#error(
        \ 'the action has not been implemented yet.',
        \ 'Not implemented error')
endfunction " }}}
function! s:action_commit(statuses, options) abort " {{{
  call s:throw_exception_except_on_commit_filetype('s:action_commit')
  " do not use a:statuses while it is a different kind of object
  let options = extend(b:gita.get('options'), a:options)
  let statuses = b:gita.get('statuses', {})
  if empty(statuses)
    " already commited. ignore
    return
  elseif empty(statuses.staged)
    " no staged files exists
    call gita#util#warn(
          \ 'there are no indexed files. add changes into the index first.',
          \ 'Commiting the changes has canceled.',
          \)
    return
  elseif &modified
    call gita#util#warn(
          \ 'there are non saved changes on the commit message. save the changes with ":w" first.',
          \ 'Commiting the changes has canceled.',
          \)
    return
  endif
  " get comment removed content
  let commitmsg = s:eliminate_comment_lines(getline(1, '$'))
  if join(commitmsg, "") =~# '\v^\s*$'
    call gita#util#warn(
          \ 'no commit messages are available. note that all lines start from "#" are eliminated.',
          \ 'Commiting the changes has canceled.',
          \)
    return
  endif
  " save comment removed content to a tempfile
  let filename = tempname()
  call writefile(commitmsg, filename)
  let fargs = ['--file', filename]
  if get(options, 'amend', 0)
    let fargs = fargs + ['--amend']
  endif
  let result = call(s:Git.commit, [fargs, { 'cwd': options.worktree_path }], s:Git)
  call delete(filename)
  if result.status == 0
    " clear cache
    call b:gita.remove('commitmsg')
    call b:gita.remove('statuses')
    " open status buffer instead
    call s:status_open()
    " show result
    call gita#util#info(result.stdout, 'The changes has been commited')
  else
    call gita#util#error(result.stdout, 'Exception')
  endif
endfunction " }}}

" gita-status buffer
function! s:status_open(...) abort " {{{
  let options = extend({
        \ 'force_construction': 0,
        \}, get(a:000, 0, {}))
  let worktree_path = s:Git.get_worktree_path(expand('%'))
  let invoker_bufnum = bufnr('%')
  " open or move to the gita-status buffer
  let manager = s:get_buffer_manager()
  let bufinfo = manager.open(s:const.status_bufname)
  if bufinfo.bufnr == -1
    call gita#util#error('vim-gita: failed to open a git status window')
    return
  endif
  " check if invoker is another gita buffer or not
  if bufname(invoker_bufnum) =~# printf('\v^%s', s:const.commit_bufname)
    " synchronize
    let a = getbufvar(invoker_bufnum, 'gita', {})
    let worktree_path = empty(a) ? worktree_path : a.get('worktree_path')
    let invoker_bufnum = empty(a) ? invoker_bufnum : a.get('invoker_bufnum')
    unlet a
  endif
  execute 'lcd ' worktree_path

  if exists('b:gita') && !options.force_construction
    let options.force_construction = 0
    call b:gita.set('options', extend(b:gita.get('options'), options))
    call b:gita.set('worktree_path', worktree_path)
    call b:gita.set('invoker_bufnum', invoker_bufnum)
    call b:gita.set('invoker_winnum', bufwinnr(invoker_bufnum))
    call s:status_update()
    return
  endif

  let b:gita = s:Cache.new()
  call b:gita.set('options', options)
  call b:gita.set('worktree_path', worktree_path)
  call b:gita.set('invoker_bufnum', invoker_bufnum)
  call b:gita.set('invoker_winnum', bufwinnr(invoker_bufnum))

  " construction
  setlocal buftype=nofile bufhidden=hide noswapfile nobuflisted
  setlocal textwidth=0
  setlocal cursorline
  setlocal winfixheight
  execute 'setlocal filetype=' . s:const.status_filetype

  " define mappings
  call s:define_mappings()

  " automatically focus invoker when the buffer is closed
  autocmd! * <buffer>
  autocmd WinLeave <buffer> call s:invoker_focus(b:gita)

  " update contents
  call s:status_update()
endfunction " }}}
function! s:status_update() abort " {{{
  call s:throw_exception_except_on_status_filetype('s:status_update')

  let worktree_path = b:gita.get('worktree_path')
  let statuses = s:GitMisc.get_parsed_status(worktree_path)
  if empty(statuses)
    " the cwd is not inside of git work tree
    bw!
    return
  elseif empty(statuses.all)
    let buflines = gita#util#flatten([
          \ s:get_header_lines(worktree_path),
          \ 'nothing to commit (working directory clean)',
          \])
    let statuses_map = {}
  else
    let buflines = s:get_header_lines(worktree_path)
    let statuses_map = {}
    for s in statuses.all
      let status_line = s:get_status_line(s)
      let statuses_map[status_line] = s
      call add(buflines, status_line)
    endfor
  endif

  " remove the entire content and rewrite the buflines
  setlocal modifiable
  let saved_cur = getpos('.')
  let saved_undolevels = &undolevels
  silent %delete _
  call setline(1, buflines)
  call setpos('.', saved_cur)
  let &undolevels = saved_undolevels
  setlocal nomodified
  setlocal nomodifiable

  call b:gita.set('statuses_map', statuses_map)
  call b:gita.set('statuses', statuses)
  redraw
endfunction " }}}

" gita-commit buffer
function! s:commit_open(...) abort " {{{
  let options = get(a:000, 0, {})
  let worktree_path = s:Git.get_worktree_path(expand('%'))
  let invoker_bufnum = bufnr('%')
  let manager = s:get_buffer_manager()
  if manager.open(s:const.commit_bufname).bufnr == -1
    call gita#util#error('vim-gita: failed to open a git commit window')
    return
  endif
  " check if invoker is another gita buffer or not
  if bufname(invoker_bufnum) =~# printf('\v^%s', s:const.status_bufname)
    " synchronize invoker_bufnum
    let a = getbufvar(invoker_bufnum, 'gita', {})
    let worktree_path = empty(a) ? worktree_path : a.get('worktree_path')
    let invoker_bufnum = empty(a) ? invoker_bufnum : a.get('invoker_bufnum')
    unlet a
  endif

  if exists('b:gita') && !get(options, 'force_construction', 0)
    let options.force_construction = 0
    call b:gita.set('options', extend(b:gita.get('options'), options))
    call b:gita.set('worktree_path', worktree_path)
    call b:gita.set('invoker_bufnum', invoker_bufnum)
    call b:gita.set('invoker_winnum', bufwinnr(invoker_bufnum))
    call s:commit_update()
    return
  endif
  execute 'lcd ' worktree_path
  let b:gita = s:Cache.new()
  call b:gita.set('options', options)
  call b:gita.set('worktree_path', worktree_path)
  call b:gita.set('invoker_bufnum', invoker_bufnum)
  call b:gita.set('invoker_winnum', bufwinnr(invoker_bufnum))

  " construction
  setlocal buftype=acwrite bufhidden=hide noswapfile nobuflisted
  setlocal winfixheight
  execute 'setlocal filetype=' . s:const.commit_filetype

  " define mappings
  call s:define_mappings()

  autocmd! * <buffer>
  autocmd BufWriteCmd <buffer> call s:commit_ac_write(expand("<amatch>"))
  autocmd WinLeave    <buffer> call s:commit_ac_leave()

  " update contents
  call s:commit_update()
endfunction " }}}
function! s:commit_update() abort " {{{
  call s:throw_exception_except_on_commit_filetype('s:commit_update')
  let worktree_path = b:gita.get('worktree_path')
  let options = b:gita.get('options')
  let is_amend = get(options, 'amend', 0)

  " update contents
  let statuses = s:GitMisc.get_parsed_status(worktree_path)
  if empty(statuses)
    bw!
    return
  endif

  " create commit comments
  let buflines = s:get_header_lines(worktree_path)
  let statuses_map = {}
  for s in statuses.all
    let status_line = printf('# %s', s:get_status_line(s))
    let statuses_map[status_line] = s
    call add(buflines, status_line)
  endfor
  if is_amend
    let buflines = buflines + ['#', '# AMEND']
  endif

  " create default commit message
  if !empty(b:gita.get('commitmsg', []))
    let buflines = b:gita.get('commitmsg') + buflines
  elseif empty(statuses.staged)
    let buflines = ['no changes added to commit'] + buflines
  elseif is_amend
    let commitmsg = s:GitMisc.get_last_commit_message(worktree_path)
    let buflines = split(commitmsg, '\v\r?\n') + buflines
  else
    let buflines = [''] + buflines
  endif

  " remove the entire content and rewrite the buflines
  setlocal modifiable
  let saved_cur = getpos('.')
  let save_undolevels = &undolevels
  setlocal undolevels=-1
  silent %delete _
  call setline(1, buflines)
  call setpos('.', saved_cur)
  let &undolevels = save_undolevels
  setlocal nomodified

  call b:gita.set('statuses_map', statuses_map)
  call b:gita.set('statuses', statuses)
  redraw
endfunction " }}}
function! s:commit_ac_write(filename) abort " {{{
  call s:throw_exception_except_on_commit_filetype('s:commit_ac_write')
  if a:filename != expand('%:p')
    " a new filename is given. save the content to the new file
    execute 'w' . (v:cmdbang ? '!' : '') fnameescape(v:cmdarg) fnameescape(a:filename)
    return
  endif
  " cache commitmsg
  let commitmsg = s:eliminate_comment_lines(getline(1, '$'))
  call b:gita.set('commitmsg', commitmsg)
  setlocal nomodified
endfunction " }}}
function! s:commit_ac_leave() abort " {{{
  call s:throw_exception_except_on_commit_filetype('s:commit_ac_write')
  " commit before leave
  call s:action_commit({}, {})
  " focus invoker
  call s:invoker_focus(b:gita)
endfunction " }}}


" Public =====================================================================
function! gita#interface#smart_map(lhs, rhs) abort " {{{
  call s:smart_map(a:lhs, a:rhs)
endfunction " }}}

function! gita#interface#status_open(...) abort " {{{
  call call('s:status_open', a:000)
endfunction " }}}
function! gita#interface#status_update() abort " {{{
  let bufnum = bufnr(s:const.status_bufname)
  let winnum = bufwinnr(bufnum)
  if winnum == -1
    call gita#util#warn(
          \ 'use "gita#interface#status_open({options})" prier to this method.',
          \ 'vim-gita: "gita-status" buffer is not opened.',
          \)
    return
  endif

  let saved_bufnum = bufnr('%')
  " focus the gita-status window
  silent execute winnum . 'wincmd w'
  " call actual update
  call s:status_update()
  " restore window focus
  silent execute bufwinnr(saved_bufnum) . 'wincmd w'
endfunction " }}}
function! gita#interface#commit_open(...) abort " {{{
  call call('s:commit_open', a:000)
endfunction " }}}
function! gita#interface#commit_update() abort " {{{
  let bufnum = bufnr(s:const.commit_bufname)
  let winnum = bufwinnr(bufnum)
  if winnum == -1
    call gita#util#warn(
          \ 'use "gita#interface#commit_open({options})" prier to this method.',
          \ 'vim-gita: "gita-commit" buffer is not opened.',
          \)
    return
  endif

  let saved_bufnum = bufnr('%')
  " focus the gita-status window
  silent execute winnum . 'wincmd w'
  " call actual update
  call s:commit_update()
  " restore window focus
  silent execute bufwinnr(saved_bufnum) . 'wincmd w'
endfunction " }}}

function! gita#interface#define_highlights() abort " {{{
  highlight default link GitaComment    Comment
  highlight default link GitaConflicted ErrorMsg
  highlight default link GitaUnstaged   WarningMsg
  highlight default link GitaStaged     Question
  highlight default link GitaUntracked  WarningMsg
  highlight default link GitaIgnored    Question
  highlight default link GitaBranch     Title
  highlight default link GitaImportant  WarningMsg
  " github
  highlight default link GitaGitHubKeyword Keyword
  highlight default link GitaGitHubIssue   Identifier
endfunction " }}}
function! gita#interface#status_define_syntax() abort " {{{
  execute 'syntax match GitaComment    /\v^#.*/'
  execute 'syntax match GitaConflicted /\v^%(DD|AU|UD|UA|DU|AA|UU)\s.*$/'
  execute 'syntax match GitaUnstaged   /\v^%([ MARC][MD]|DM)\s.*$/'
  execute 'syntax match GitaStaged     /\v^[MADRC]\s\s.*$/'
  execute 'syntax match GitaUntracked  /\v^\?\?\s.*$/'
  execute 'syntax match GitaIgnored    /\v^!!\s.*$/'
  execute 'syntax match GitaComment    /\v^# On branch/ contained'
  execute 'syntax match GitaBranch     /\v^# On branch .*$/hs=s+12 contains=GitaComment'
endfunction " }}}
function! gita#interface#commit_define_syntax() abort " {{{
  execute 'syntax match GitaComment    /\v^#.*/'
  execute 'syntax match GitaComment    /\v^# / contained'
  execute 'syntax match GitaConflicted /\v^# %(DD|AU|UD|UA|DU|AA|UU)\s.*$/hs=s+2 contains=GitaComment'
  execute 'syntax match GitaUnstaged   /\v^# %([ MARC][MD]|DM)\s.*$/hs=s+2 contains=GitaComment'
  execute 'syntax match GitaStaged     /\v^# [MADRC] \s.*$/hs=s+2 contains=GitaComment'
  execute 'syntax match GitaUntracked  /\v^# \?\?\s.*$/hs=s+2 contains=GitaComment'
  execute 'syntax match GitaIgnored    /\v^# !!\s.*$/hs=s+2 contains=GitaComment'
  execute 'syntax match GitaImportant  /\v^# AMEND$/hs=s+2 contains=GitaComment'
  execute 'syntax match GitaComment    /\v^# On branch/ contained'
  execute 'syntax match GitaBranch     /\v^# On branch .*$/hs=s+12 contains=GitaComment'
  " github
  execute 'syntax keyword GitaGitHubKeyword close closes closed fix fixes fixed resolve resolves resolved'
  execute 'syntax match   GitaGitHubIssue   "\v%([^ /#]+/[^ /#]+#\d+|#\d+)"'
endfunction " }}}

" Assign constant variables
if !exists('s:const')
  let s:const = g:gita#interface#const
endif

let &cpo = s:save_cpo
unlet s:save_cpo
"vim: sts=2 sw=2 smarttab et ai textwidth=0 fdm=marker
