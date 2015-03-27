"******************************************************************************
" vim-gita ui status
"
" Author:   Alisue <lambdalisue@hashnote.net>
" URL:      http://hashnote.net/
" License:  MIT license
" (C) 2015, Alisue, hashnote.net
"******************************************************************************
let s:save_cpo = &cpo
set cpo&vim


" Vital modules ==============================================================
let s:Path          = gita#util#import('System.Filepath')
let s:Dict          = gita#util#import('Data.Dict')
let s:Buffer        = gita#util#import('Vim.Buffer')
let s:BufferManager = gita#util#import('Vim.BufferManager')
let s:Git           = gita#util#import('VCS.Git')

" Utility functions
function! s:get_header_lines(gita) abort " {{{
  let meta = a:gita.git.get_meta()
  let c = a:gita.get_comment_char()
  let n = fnamemodify(a:gita.git.worktree, ':t')
  let b = meta.current_branch
  let r = printf('%s/%s',
        \   meta.current_branch_remote,
        \   meta.current_remote_branch,
        \ )
  let o = a:gita.git.count_commits_ahead_of_remote()
  let i = a:gita.git.count_commits_behind_remote()

  let buflines = []
  if strlen(r) > 1
    call add(buflines, printf('%s On branch %s/%s -> %s', c, n, b, r))
  else
    call add(buflines, printf('%s On branch %s/%s', c, n, b))
  endif
  if o > 0 && i > 0
    call add(buflines, printf(
          \ '%s This branch is %d commit(s) ahead of and %d commit(s) behind %s',
          \ c, o, i, r
          \))
  elseif o > 0
    call add(buflines, printf(
          \ '%s This branch is %d commit(s) ahead of %s',
          \ c, o, r
          \))
  elseif i > 0
    call add(buflines, printf(
          \ '%s This branch is %d commit(s) behind %s',
          \ c, i, r
          \))
  endif
  return buflines
endfunction " }}}
function! s:get_status_line(status) abort " {{{
  return a:status.record
endfunction " }}}
function! s:unlet(name) abort " {{{
  if exists(a:name)
    execute 'unlet' a:name
  endif
endfunction " }}}
function! s:smart_map(lhs, rhs) abort " {{{
  call s:validate_filetype('s:smart_map')
  " return {rhs} if the mapping is called on Git status line of status/commit
  " buffer. otherwise it return {lhs}
  let ret = s:get_selected_status()
  return empty(ret) ? a:lhs : a:rhs
endfunction " }}}
function! s:define_mappings() abort " {{{
  call s:validate_filetype('s:define_mappings')

  nnoremap <buffer><silent> <Plug>(gita-action-status-open)         :<C-u>call <SID>action('status_open', 0)<CR>
  nnoremap <buffer><silent> <Plug>(gita-action-status-update)       :<C-u>call <SID>action('status_update', 0)<CR>
  nnoremap <buffer><silent> <Plug>(gita-action-commit)              :<C-u>call <SID>action('commit', 0)<CR>
  nnoremap <buffer><silent> <Plug>(gita-action-commit-open)         :<C-u>call <SID>action('commit_open', 0)<CR>
  nnoremap <buffer><silent> <Plug>(gita-action-commit-open-amend)   :<C-u>call <SID>action('commit_open', 0, { 'amend': 1 })<CR>
  nnoremap <buffer><silent> <Plug>(gita-action-commit-open-noamend) :<C-u>call <SID>action('commit_open', 0, { 'amend': 0 })<CR>
  nnoremap <buffer><silent> <Plug>(gita-action-commit-update)       :<C-u>call <SID>action('commit_update', 0)<CR>

  nnoremap <buffer><silent> <Plug>(gita-action-open-edit)   :<C-u>call <SID>action('open', 0, { 'opener': 'edit' })<CR>
  nnoremap <buffer><silent> <Plug>(gita-action-open-left)   :<C-u>call <SID>action('open', 0, { 'opener': 'left' })<CR>
  nnoremap <buffer><silent> <Plug>(gita-action-open-right)  :<C-u>call <SID>action('open', 0, { 'opener': 'right' })<CR>
  nnoremap <buffer><silent> <Plug>(gita-action-open-above)  :<C-u>call <SID>action('open', 0, { 'opener': 'above' })<CR>
  nnoremap <buffer><silent> <Plug>(gita-action-open-below)  :<C-u>call <SID>action('open', 0, { 'opener': 'below' })<CR>
  nnoremap <buffer><silent> <Plug>(gita-action-open-split)  :<C-u>call <SID>action('open', 0, { 'opener': 'split' })<CR>
  nnoremap <buffer><silent> <Plug>(gita-action-open-vsplit) :<C-u>call <SID>action('open', 0, { 'opener': 'vsplit' })<CR>
  nnoremap <buffer><silent> <Plug>(gita-action-diff-hori)   :<C-u>call <SID>action('diff', 0, { 'vertical': 0 })<CR>
  nnoremap <buffer><silent> <Plug>(gita-action-diff-vert)   :<C-u>call <SID>action('diff', 0, { 'vertical': 1 })<CR>

  vnoremap <buffer><silent> <Plug>(gita-action-open-edit)   :<C-u>call <SID>action('open', 1, { 'opener': 'edit' })<CR>
  vnoremap <buffer><silent> <Plug>(gita-action-open-left)   :<C-u>call <SID>action('open', 1, { 'opener': 'left' })<CR>
  vnoremap <buffer><silent> <Plug>(gita-action-open-right)  :<C-u>call <SID>action('open', 1, { 'opener': 'right' })<CR>
  vnoremap <buffer><silent> <Plug>(gita-action-open-above)  :<C-u>call <SID>action('open', 1, { 'opener': 'above' })<CR>
  vnoremap <buffer><silent> <Plug>(gita-action-open-below)  :<C-u>call <SID>action('open', 1, { 'opener': 'below' })<CR>
  vnoremap <buffer><silent> <Plug>(gita-action-open-split)  :<C-u>call <SID>action('open', 1, { 'opener': 'split' })<CR>
  vnoremap <buffer><silent> <Plug>(gita-action-open-vsplit) :<C-u>call <SID>action('open', 1, { 'opener': 'vsplit' })<CR>
  vnoremap <buffer><silent> <Plug>(gita-action-diff-hori)   :<C-u>call <SID>action('diff', 1, { 'vertical': 0 })<CR>
  vnoremap <buffer><silent> <Plug>(gita-action-diff-vert)   :<C-u>call <SID>action('diff', 1, { 'vertical': 1 })<CR>
  
  if &filetype == s:const.status_filetype
    nnoremap <buffer><silent> <Plug>(gita-action-add)         :<C-u>call <SID>action('add', 0)<CR>
    nnoremap <buffer><silent> <Plug>(gita-action-ADD)         :<C-u>call <SID>action('add', 0, { 'force': 1 })<CR>
    nnoremap <buffer><silent> <Plug>(gita-action-rm)          :<C-u>call <SID>action('rm_cached', 0)<CR>
    nnoremap <buffer><silent> <Plug>(gita-action-RM)          :<C-u>call <SID>action('rm_cached', 0, { 'force': 1 })<CR>
    nnoremap <buffer><silent> <Plug>(gita-action-checkout)    :<C-u>call <SID>action('checkout', 0)<CR>
    nnoremap <buffer><silent> <Plug>(gita-action-CHECKOUT)    :<C-u>call <SID>action('checkout', 0, { 'force': 1 })<CR>
    nnoremap <buffer><silent> <Plug>(gita-action-toggle)      :<C-u>call <SID>action('toggle', 0)<CR>
    nnoremap <buffer><silent> <Plug>(gita-action-TOGGLE)      :<C-u>call <SID>action('toggle', 0, { 'force': 1 })<CR>
    nnoremap <buffer><silent> <Plug>(gita-action-discard)     :<C-u>call <SID>action('discard', 0)<CR>
    nnoremap <buffer><silent> <Plug>(gita-action-DISCARD)     :<C-u>call <SID>action('discard', 0, { 'force': 1 })<CR>

    vnoremap <buffer><silent> <Plug>(gita-action-add)         :<C-u>call <SID>action('add', 1)<CR>
    vnoremap <buffer><silent> <Plug>(gita-action-ADD)         :<C-u>call <SID>action('add', 1, { 'force': 1 })<CR>
    vnoremap <buffer><silent> <Plug>(gita-action-rm)          :<C-u>call <SID>action('rm_cached', 1)<CR>
    vnoremap <buffer><silent> <Plug>(gita-action-RM)          :<C-u>call <SID>action('rm_cached', 1, { 'force': 1 })<CR>
    vnoremap <buffer><silent> <Plug>(gita-action-checkout)    :<C-u>call <SID>action('checkout', 1)<CR>
    vnoremap <buffer><silent> <Plug>(gita-action-CHECKOUT)    :<C-u>call <SID>action('checkout', 1, { 'force': 1 })<CR>
    vnoremap <buffer><silent> <Plug>(gita-action-toggle)      :<C-u>call <SID>action('toggle', 1)<CR>
    vnoremap <buffer><silent> <Plug>(gita-action-TOGGLE)      :<C-u>call <SID>action('toggle', 1, { 'force': 1 })<CR>
    vnoremap <buffer><silent> <Plug>(gita-action-discard)     :<C-u>call <SID>action('discard', 1)<CR>
    vnoremap <buffer><silent> <Plug>(gita-action-DISCARD)     :<C-u>call <SID>action('discard', 1, { 'force': 1 })<CR>
  endif

  if get(g:, 'gita#ui#status#enable_default_keymaps', 1)
    nmap <buffer>       q      :<C-u>q<CR>
    nmap <buffer><expr> <CR>   <SID>smart_map('<CR>',   '<Plug>(gita-action-open-edit)')
    nmap <buffer><expr> <S-CR> <SID>smart_map('<S-CR>', '<Plug>(gita-action-diff-vsplit)')
    nmap <buffer><expr> e      <SID>smart_map('e',      '<Plug>(gita-action-open-edit)')
    nmap <buffer><expr> E      <SID>smart_map('E',      '<Plug>(gita-action-open-vsplit)')
    nmap <buffer><expr> <C-e>  <SID>smart_map('<C-e>',  '<Plug>(gita-action-open-split)')
    nmap <buffer><expr> d      <SID>smart_map('d',      '<Plug>(gita-action-diff-vert)')
    nmap <buffer><expr> D      <SID>smart_map('D',      '<Plug>(gita-action-diff-vert)')
    nmap <buffer><expr> <C-d>  <SID>smart_map('<C-d>',  '<Plug>(gita-action-diff-hori)')

    if &filetype == s:const.status_filetype
      nmap <buffer> <C-l> <Plug>(gita-action-status-update)
      nmap <buffer> cc    <Plug>(gita-action-commit-open)
      nmap <buffer> cA    <Plug>(gita-action-commit-open-amend)
      nmap <buffer> cC    <Plug>(gita-action-commit-open-noamend)

      nmap <buffer><expr> -a <SID>smart_map('-a', '<Plug>(gita-action-add)')
      nmap <buffer><expr> -A <SID>smart_map('-A', '<Plug>(gita-action-ADD)')
      nmap <buffer><expr> -r <SID>smart_map('-r', '<Plug>(gita-action-rm)')
      nmap <buffer><expr> -R <SID>smart_map('-R', '<Plug>(gita-action-RM)')
      nmap <buffer><expr> -c <SID>smart_map('-c', '<Plug>(gita-action-checkout)')
      nmap <buffer><expr> -C <SID>smart_map('-C', '<Plug>(gita-action-CHECKOUT)')
      nmap <buffer><expr> -- <SID>smart_map('--', '<Plug>(gita-action-toggle)')
      nmap <buffer><expr> -= <SID>smart_map('-=', '<Plug>(gita-action-TOGGLE)')
      nmap <buffer><expr> -d <SID>smart_map('-d', '<Plug>(gita-action-discard)')

      vmap <buffer>       -a <Plug>(gita-action-add)
      vmap <buffer>       -A <Plug>(gita-action-ADD)
      vmap <buffer>       -r <Plug>(gita-action-rm)
      vmap <buffer>       -R <Plug>(gita-action-RM)
      vmap <buffer>       -c <Plug>(gita-action-checkout)
      vmap <buffer>       -C <Plug>(gita-action-CHECKOUT)
      vmap <buffer>       -- <Plug>(gita-action-toggle)
      vmap <buffer>       -= <Plug>(gita-action-TOGGLE)
      vmap <buffer>       -d <Plug>(gita-action-discard)
    else
      nmap <buffer> <C-l> <Plug>(gita-action-commit-update)
      nmap <buffer> cc    <Plug>(gita-action-status-open)
      nmap <buffer> CC    <Plug>(gita-action-commit)
    endif
  endif
endfunction " }}}
function! s:get_selected_status() abort " {{{
  call s:validate_filetype('s:get_selected_status')
  let statuses_map = b:_statuses_map
  let selected_line = getline('.')
  return get(statuses_map, selected_line, {})
endfunction " }}}
function! s:get_selected_statuses() abort " {{{
  call s:validate_filetype('s:get_selected_statuses')
  let statuses_map = b:_statuses_map
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

" Validation
function! s:validate_filetype(...) abort " {{{
  let fname = get(a:000, 0, 'function')
  if &filetype !=# s:const.status_filetype && &filetype !=# s:const.commit_filetype
    throw printf('vim-gita: %s required to be executed on a proper filetype buffer', fname)
  endif
endfunction " }}}
function! s:validate_filetype_status(...) abort " {{{
  let fname = get(a:000, 0, 'function')
  if &filetype !=# s:const.status_filetype
    throw printf('vim-gita: %s required to be executed on a status filetype buffer', fname)
  endif
endfunction " }}}
function! s:validate_filetype_commit(...) abort " {{{
  let fname = get(a:000, 0, 'function')
  if &filetype !=# s:const.commit_filetype
    throw printf('vim-gita: %s required to be executed on a commit filetype buffer', fname)
  endif
endfunction " }}}
function! s:validate_status_add(status, options) abort " {{{
  if a:status.is_conflicted
    call gita#util#error(
          \ printf('The behavior of adding a conflicted file "%s" to the index has not been defined yet.', a:status.path
          \)
    return 1
  endif

  if !a:status.is_unstaged && !a:status.is_untracked && !a:status.is_ignored
    call gita#util#info(
          \ printf('No changes of "%s" exists on the work tree (All changes has been staged)', a:status.path)
          \)
    return 1
  elseif a:status.is_ignored && !get(a:options, 'force', 0)
    call gita#util#info(
          \ printf('An ignored file "%s" cannot be added to the index. Use <Plug>(gita-action-ADD) instead.', a:status.path)
          \)
    return 1
  endif
  return 0
endfunction " }}}
function! s:validate_status_rm_cached(status, options) abort " {{{
  if a:status.is_conflicted
    call gita#util#error(
          \ printf('The behavior of removing a conflicted file "%s" from the index has not been defined yet.', a:status.path
          \)
    return 1
  endif

  if a:status.is_ignored || a:status.is_untracked
    call gita#util#info(
          \ printf('An untracked file "%s" cannot be removed from the index.', a:status.path)
          \)
    return 1
  elseif !a:status.is_staged
    call gita#util#info(
          \ printf('No changes of "%s" exists on the index (No changes has been staged)', a:status.path)
          \)
    return 1
  endif
  return 0
endfunction " }}}
function! s:validate_status_checkout(status, options) abort " {{{
  if a:status.is_conflicted
    call gita#util#error(
          \ printf('The behavior of checking out a conflicted file "%s" to the work tree has not been defined yet.', a:status.path
          \)
    return 1
  endif

  if a:status.is_ignored || a:status.is_untracked
    call gita#util#info(
          \ printf('An untracked file "%s" cannot be checked out to the work tree.', a:status.path)
          \)
    return 1
  elseif a:status.is_unstaged && !get(a:options, 'force', 0)
    call gita#util#info(
          \ printf('An unstaged file "%s" cannot be checked out to the work tree. Use <Plug>(gita-action-CHECKOUT) instead.', a:status.path)
          \)
    return 1
  endif
  return 0
endfunction " }}}
function! s:validate_status_toggle(status, options) abort " {{{
  if a:status.is_conflicted
    call gita#util#error(
          \ printf('The behavior of toggling a conflicted file "%s" from/to the work tree has not been defined yet.', a:status.path
          \)
    return 1
  endif
  return 0
endfunction " }}}
function! s:validate_status_discard(status, options) abort " {{{
  if a:status.is_conflicted
    call gita#util#error(
          \ printf('The behavior of discarding the changes on a conflicted file "%s" has not been defined yet.', a:status.path
          \)
    return 1
  endif
  return 0
endfunction " }}}

" Buffer
function! s:buffer_get_manager() abort " {{{
  if !exists('s:buffer_manager')
    let config = {
          \ 'opener': 'topleft 20 split',
          \ 'range': 'tabpage',
          \}
    let s:buffer_manager = s:BufferManager.new(config)
  endif
  return s:buffer_manager
endfunction " }}}
function! s:buffer_open(name) abort " {{{
  let manager = s:buffer_get_manager()
  return manager.open(a:name)
endfunction " }}}
function! s:buffer_update(buflines) abort " {{{
  call s:validate_filetype('s:buffer_update')
  let saved_cur = getpos('.')
  let saved_undolevels = &undolevels
  silent %delete _
  call setline(1, a:buflines)
  call setpos('.', saved_cur)
  let &undolevels = saved_undolevels
  setlocal nomodified
endfunction " }}}

" Invoker
function! s:invoker_get(...) abort " {{{
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
function! s:invoker_set(invoker, ...) abort " {{{
  let bufname = get(a:000, 0, '%')
  call setbufvar(bufname, '_invoker', a:invoker)
endfunction " }}}
function! s:invoker_get_winnum(invoker) abort " {{{
  let bufnum = a:invoker.bufnum
  let winnum = bufwinnr(bufnum)
  if winnum == -1
    let winnum = a:invoker.winnum
  endif
  return winnum
endfunction " }}}
function! s:invoker_focus(invoker) abort " {{{
  let winnum = s:invoker_get_winnum(a:invoker)
  if winnum <= winnr('$')
    silent execute winnum . 'wincmd w'
  else
    silent execute 'wincmd p'
  endif
endfunction " }}}

" Options
function! s:options_get(...) abort " {{{
  let bufname = get(a:000, 0, '%')
  return getbufvar(bufname, '_options', {})
endfunction " }}}
function! s:options_set(options, ...) abort " {{{
  let bufname = get(a:000, 0, '%')
  call setbufvar(bufname, '_options', a:options)
endfunction " }}}

" Action
function! s:action(name, multi, ...) abort " {{{
  call s:validate_filetype('s:action')
  let options = extend(s:options_get(), get(a:000, 0, {}))
  if a:multi
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
      \ 'status_open',
      \ 'status_update',
      \ 'commit_open',
      \ 'commit_update',
      \ 'commit',
      \]
let s:statuses_optional_actions_pattern =
      \ printf('\v%%(%s)', join(s:statuses_optional_actions, '|'))
" }}}
function! s:action_status_open(statuses, options) abort " {{{
  if &modified && !get(a:options, 'force', 0)
    call gita#util#warn('The changes has not been saved. Use ":w" to save the changes first.')
    return
  endif
  call s:status_open(a:options)
endfunction " }}}
function! s:action_status_update(statuses, options) abort " {{{
  if &modified && !get(a:options, 'force', 0)
    call gita#util#warn('The changes has not been saved. Use ":w" to save the changes first.')
    return
  endif
  call s:status_update()
endfunction " }}}
function! s:action_commit_open(statuses, options) abort " {{{
  if &modified && !get(a:options, 'force', 0)
    call gita#util#warn('The changes has not been saved. Use ":w" to save the changes first.')
    return
  endif
  call s:commit_open(a:options)
endfunction " }}}
function! s:action_commit_update(statuses, options) abort " {{{
  if &modified && !get(a:options, 'force', 0)
    call gita#util#warn('The changes has not been saved. Use ":w" to save the changes first.')
    return
  endif
  call s:commit_update()
endfunction " }}}
function! s:action_add(statuses, options) abort " {{{
  let options = extend({ 'force': 0 }, a:options)
  " eliminate invalid statuses
  let valid_statuses = []
  for status in a:statuses
    if s:validate_status_add(status, options)
      continue
    endif
    call add(valid_statuses, status)
  endfor
  if empty(valid_statuses)
    call gita#util#warn('No valid files were selected. The operation is canceled.')
    return
  endif
  let result = gita#get().git.add(options, map(valid_statuses, 'v:val.path'))
  if result.status == 0
    call s:status_update()
  else
    call gita#util#error(
          \ result.stdout,
          \ printf('Fail: %s', join(result.args)),
          \)
  endif
endfunction " }}}
function! s:action_rm_cached(statuses, options) abort " {{{
  let options = extend({ 'force': 0 }, a:options)
  let options.cached = 1
  " eliminate invalid statuses
  let valid_statuses = []
  for status in a:statuses
    if s:validate_status_rm_cached(status, options)
      continue
    endif
    call add(valid_statuses, status)
  endfor
  if empty(valid_statuses)
    call gita#util#warn('No valid files were selected. The operation is canceled.')
    return
  endif
  let result = gita#get().git.rm(options, map(valid_statuses, 'v:val.path'))
  if result.status == 0
    call s:status_update()
  else
    call gita#util#error(
          \ result.stdout,
          \ printf('Fail: %s', join(result.args)),
          \)
  endif
endfunction " }}}
function! s:action_checkout(statuses, options) abort " {{{
  let options = extend({ 'force': 0 }, a:options)
  let commit = gita#util#ask('Checkout from: ', 'HEAD')
  if strlen(commit) == 0
    redraw || call gita#util#info('No valid commit was selected. The operation is canceled.')
    return
  endif
  " eliminate invalid statuses
  let valid_statuses = []
  for status in a:statuses
    if s:validate_status_checkout(status, options)
      continue
    endif
    call add(valid_statuses, status)
  endfor
  if empty(valid_statuses)
    call gita#util#warn('No valid files were selected. The operation is canceled.')
    return
  endif
  let result = gita#get().git.checkout(options, commit, map(valid_statuses, 'v:val.path'))
  if result.status == 0
    call s:status_update()
  else
    call gita#util#error(
          \ result.stdout,
          \ printf('Fail: %s', join(result.args)),
          \)
  endif
endfunction " }}}
function! s:action_toggle(statuses, options) abort " {{{
  " classify statuses
  let add_statuses = []
  let rm_cached_statuses = []
  for status in a:statuses
    if s:validate_status_toggle(status, a:options)
      continue
    endif
    if status.is_staged && status.is_unstaged
      if get(g:, 'gita#ui#status#toggle_prefer_rm_cached', 0)
        call add(rm_cached_statuses, status)
      else
        call add(add_statuses, status)
      endif
    elseif status.is_staged
        call add(rm_cached_statuses, status)
    else
        call add(add_statuses, status)
    endif
  endfor
  if empty(add_statuses) && empty(rm_cached_statuses)
    call gita#util#warn('No valid files were selected. The operation is canceled.')
    return
  endif
  if !empty(add_statuses)
    call s:action_add(add_statuses, a:options)
  endif
  if !empty(rm_cached_statuses)
    call s:action_rm_cached(rm_cached_statuses, a:options)
  endif
endfunction " }}}
function! s:action_discard(statuses, options) abort " {{{
  let options = extend({ 'force': 0 }, a:options)
  " eliminate invalid statuses
  let remove_statuses = []
  let checkout_statuses = []
  for status in a:statuses
    if s:validate_status_discard(status, options)
      continue
    endif
    if status.is_untracked || status.is_ignored
      call add(remove_statuses, status)
    else
      call add(checkout_statuses, status)
    endif
  endfor
  if empty(remove_statuses) && empty(checkout_statuses)
    call gita#util#warn('No valid files were selected. The operation is canceled.')
    return
  endif
  if !get(options, 'force', 0)
    call gita#util#warn(
          \ 'All changes of the following files on the INDEX and the WORK TREE will be discarded, mean that the operation can NOT revert.',
          \ 'Operation cannot revert:'
          \)
    for remove_status in remove_statuses
      echo printf('- [DELETE] %s', remove_status.path)
    endfor
    for checkout_status in checkout_statuses
      echo printf('- [RESET ] %s', checkout_status.path)
    endfor
    let r = gita#util#asktf('Are you sure that you want to discard the changes?')
    if !r
      redraw | call gita#util#info('The operation has canceled by user.')
      return
    endif
  endif
  for remove_status in remove_statuses
    call delete(remove_status.path)
  endfor
  " the following is like 'git reset --hard -- <files>'
  let result = gita#get().git.checkout(options, 'HEAD', map(checkout_statuses, 'v:val.path'))
  if result.status == 0
    call s:status_update()
  else
    call gita#util#error(
          \ result.stdout,
          \ printf('Fail: %s', join(result.args)),
          \)
  endif
endfunction " }}}
function! s:action_open(statuses, options) abort " {{{
  let options = extend({ 'opener': 'edit' }, a:options)
  let opener = get(g:gita#ui#status#opener_aliases, options.opener, options.opener)
  let gita = gita#get()
  let invoker_winnum = s:invoker_get_winnum(s:invoker_get())
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
  let options = extend({ 'vertical': 1 }, a:options)
  let opener = get(g:gita#ui#status#opener_aliases, 'edit', 'edit')
  let gita = gita#get()
  let invoker_winnum = s:invoker_get_winnum(s:invoker_get())
  if invoker_winnum != -1
    silent execute invoker_winnum . 'wincmd w'
  else
    silent execute 'wincmd p'
  endif
  let commit = gita#util#ask('Which commit do you want to compare with? ', 'HEAD')
  if strlen(commit) == 0
    call gita#util#warn('Operation has canceled by user.')
    return
  endif
  " open the selected status files
  for status in a:statuses
    let path = get(status, 'path2', status.path)
    call s:Buffer.open(path, opener)
    call gita#ui#diff#diffthis(commit, options)
  endfor
endfunction " }}}
function! s:action_commit(statuses, options) abort " {{{
  " do not use a:statuses while it is a different kind of object
  let gita = gita#get()
  let options = extend(s:options_get(), a:options)
  let statuses = get(b:, '_statuses', {})
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
  let c = gita.get_comment_char()
  let commitmsg = filter(getline(1, '$'), printf('v:val !~# "^%s"', c))
  if join(commitmsg, "") =~# '\v^\s*$'
    call gita#util#warn(
          \ printf('no commit messages are available. note that all lines start from "%s" are eliminated.', c),
          \ 'Commiting the changes has canceled.',
          \)
    return
  endif
  " save comment removed content to a tempfile
  let filename = tempname()
  call writefile(commitmsg, filename)
  let options.file = filename
  call gita#call_hooks('commit', 'pre', options)
  let result = gita#get().git.commit(options)
  if result.status == 0
    " clear cache
    call delete(filename)
    call s:unlet('b:_options')
    call s:unlet('b:_commitmsg')
    call s:unlet('b:_statuses')
    call s:unlet('b:_statuses_map')
    " call hooks and update buffer
    call gita#call_hooks('commit', 'post', options)
    call s:commit_update()
  else
    call gita#util#error(
          \ result.stdout,
          \ printf('Fail: %s', join(result.args)),
          \)
  endif
endfunction " }}}

" Status/Commit window
function! s:status_open(...) abort " {{{
  let opts = extend({
        \ 'force_construction': 0,
        \}, get(a:000, 0, {}))
  let gita = gita#get()
  let invoker = s:invoker_get()
  let options = extend(
        \ s:options_get(),
        \ s:Dict.omit(opts, [
        \   'force_construction',
        \]))
  " open or move to the interface buffer
  if s:buffer_open(s:const.status_bufname).bufnr == -1
    throw 'vim-gita: failed to open a git status window'
  endif
  execute 'setlocal filetype=' . s:const.status_filetype
  " check if gita is available
  if !gita.is_enable
    let cached_gita = gita#get()
    if get(cached_gita, 'is_enable', 0)
      " invoker is not in Git directory but the interface has cache so use the
      " cache to display the status window
      let gita = cached_gita
      unlet cached_gita
    else
      " nothing can do. close the window and exit.
      redraw
      call gita#util#warn('Not in git working tree')
      close!
      return
    endif
  endif

  " cache instances
  call gita#set(gita)
  call s:invoker_set(invoker)
  call s:options_set(options)

  " check if construction is required
  if exists('b:_constructed') && !opts.force_construction
    " construction is not required.
    call s:status_update()
    return
  endif
  let b:_constructed = 1

  " construction
  setlocal buftype=nofile bufhidden=hide noswapfile nobuflisted
  setlocal textwidth=0
  setlocal cursorline
  setlocal winfixheight

  " define mappings
  call s:define_mappings()

  " automatically focus invoker when the buffer is closed
  autocmd! * <buffer>
  autocmd WinLeave <buffer> call s:status_ac_leave()

  " update contents
  call s:status_update()
endfunction " }}}
function! s:status_update() abort " {{{
  call s:validate_filetype_status('s:status_update')
  let gita = gita#get()
  if !gita.is_enable
    redraw
    call gita#util#warn('Not in git working tree')
    close!
    return
  endif

  let options = s:options_get()
  let statuses = gita.git.get_parsed_status(extend({ 'no_cache': 1 }, options))
  if get(statuses, 'status', 0)
    call gita#util#error(
          \ statuses.stdout,
          \ printf('Fail: %s', join(statuses.args))
          \)
    close!
    return
  endif

  " create status message
  let buflines = s:get_header_lines(gita)
  let statuses_map = {}
  for s in statuses.all
    let status_line = printf('%s', s:get_status_line(s))
    let statuses_map[status_line] = s
    call add(buflines, status_line)
  endfor

  " create status messages
  let statusmsg = []
  if empty(statuses.all)
    let statusmsg = ['nothing to commit (working directory clean']
  endif
  let bufline = statusmsg + buflines

  " remove the entire content and rewrite the buflines
  setlocal modifiable
  call s:buffer_update(buflines)
  setlocal nomodifiable

  let b:_statuses = statuses
  let b:_statuses_map = statuses_map
  redraw
endfunction " }}}
function! s:status_ac_leave() abort " {{{
  call s:validate_filetype_status('s:status_ac_leave')
  call s:invoker_focus(s:invoker_get())
endfunction " }}}
function! s:commit_open(...) abort " {{{
  let opts = extend({
        \ 'force_construction': 0,
        \}, get(a:000, 0, {}))
  let gita = gita#get()
  let invoker = s:invoker_get()
  let options = extend(
        \ s:options_get(),
        \ s:Dict.omit(opts, [
        \   'force_construction',
        \]))
  " open or move to the interface buffer
  if s:buffer_open(s:const.commit_bufname).bufnr == -1
    throw 'vim-gita: failed to open a git commit window'
  endif
  execute 'setlocal filetype=' . s:const.commit_filetype
  " check if gita is available
  if !gita.is_enable
    let cached_gita = gita#get()
    if get(cached_gita, 'is_enable', 0)
      " invoker is not in Git directory but the interface has cache so use the
      " cache to display the status window
      let gita = cached_gita
      unlet cached_gita
    else
      " nothing can do. close the window and exit.
      redraw
      call gita#util#warn('Not in git working tree')
      close!
      return
    endif
  endif

  " cache instances
  call gita#set(gita)
  call s:invoker_set(invoker)
  call s:options_set(options)

  " check if construction is required
  if exists('b:_constructed') && !opts.force_construction
    " construction is not required.
    call s:commit_update()
    return
  endif
  let b:_constructed = 1

  " construction
  setlocal buftype=acwrite bufhidden=hide noswapfile nobuflisted
  setlocal winfixheight

  " define mappings
  call s:define_mappings()

  " automatically focus invoker when the buffer is closed
  autocmd! * <buffer>
  autocmd BufWriteCmd <buffer> call s:commit_ac_write(expand("<amatch>"))
  autocmd WinLeave    <buffer> call s:commit_ac_leave()

  " update contents
  call s:commit_update()
endfunction " }}}
function! s:commit_update() abort " {{{
  call s:validate_filetype_commit('s:commit_update')
  let gita = gita#get()
  if !gita.is_enable
    call gita#util#warn('Not in git working tree')
    close!
    return
  endif
  let c = gita.get_comment_char()

  let options = s:options_get()
  let statuses = gita.git.get_parsed_commit(extend({ 'no_cache': 1 }, options))
  if get(statuses, 'status', 0)
    call gita#util#error(
          \ statuses.stdout,
          \ printf('Fail: %s', join(statuses.args))
          \)
    close!
    return
  endif

  " create status message
  let buflines = s:get_header_lines(gita)
  let statuses_map = {}
  for s in statuses.all
    let status_line = printf('%s %s', c, s:get_status_line(s))
    let statuses_map[status_line] = s
    call add(buflines, status_line)
  endfor

  " create default commit message
  let commitmsg = ['']
  if exists('b:_commitmsg')
    let commitmsg = b:_commitmsg
  elseif get(options, 'amend', 0)
    let commitmsg = gita.git.get_last_commitmsg()
    let commitmsg = commitmsg + [printf('%s AMEND', c)]
  elseif empty(statuses.staged)
    let commitmsg = ['no changes added to commit']
  endif
  let buflines = commitmsg + buflines

  " remove the entire content and rewrite the buflines
  setlocal modifiable
  call s:buffer_update(buflines)

  let b:_statuses = statuses
  let b:_statuses_map = statuses_map
  redraw
endfunction " }}}
function! s:commit_ac_write(filename) abort " {{{
  call s:validate_filetype_commit('s:commit_ac_write')
  if a:filename != expand('%:p')
    " a new filename is given. save the content to the new file
    execute 'w' . (v:cmdbang ? '!' : '') fnameescape(v:cmdarg) fnameescape(a:filename)
    return
  endif
  " cache commitmsg
  let gita = gita#get()
  let c = gita.get_comment_char()
  let b:_commitmsg = filter(getline(1, '$'), printf('v:val !~# "^%s"', c))
  setlocal nomodified
endfunction " }}}
function! s:commit_ac_leave() abort " {{{
  call s:validate_filetype_commit('s:commit_ac_leave')
  " commit before leave
  call s:action_commit({}, {})
  " focus invoker
  call s:invoker_focus(s:invoker_get())
endfunction " }}}

" Public
function! gita#ui#status#status_open(...) abort " {{{
  call call('s:status_open', a:000)
endfunction " }}}
function! gita#ui#status#commit_open(...) abort " {{{
  call call('s:commit_open', a:000)
endfunction " }}}
function! gita#ui#status#define_highlights() abort " {{{
  highlight default link GitaComment    Comment
  highlight default link GitaConflicted ErrorMsg
  highlight default link GitaUnstaged   WarningMsg
  highlight default link GitaStaged     Question
  highlight default link GitaUntracked  WarningMsg
  highlight default link GitaIgnored    Question
  highlight default link GitaBranch     Title
  highlight default link GitaImportant  Tag
  " github
  highlight default link GitaGitHubKeyword Keyword
  highlight default link GitaGitHubIssue   Identifier
endfunction " }}}
function! gita#ui#status#status_define_syntax() abort " {{{
  execute 'syntax match GitaComment    /\v^#.*/'
  execute 'syntax match GitaConflicted /\v^%(DD|AU|UD|UA|DU|AA|UU)\s.*$/'
  execute 'syntax match GitaUnstaged   /\v^%([ MARC][MD]|DM)\s.*$/'
  execute 'syntax match GitaStaged     /\v^[MADRC]\s\s.*$/'
  execute 'syntax match GitaUntracked  /\v^\?\?\s.*$/'
  execute 'syntax match GitaIgnored    /\v^!!\s.*$/'
  execute 'syntax match GitaComment    /\v^# On branch/ contained'
  execute 'syntax match GitaBranch     /\v^# On branch .*$/hs=s+12 contains=GitaComment'
endfunction " }}}
function! gita#ui#status#commit_define_syntax() abort " {{{
  execute 'syntax match GitaComment    /\v^#.*/'
  execute 'syntax match GitaComment    /\v^# / contained'
  execute 'syntax match GitaConflicted /\v^# %(DD|AU|UD|UA|DU|AA|UU)\s.*$/hs=s+2 contains=GitaComment'
  execute 'syntax match GitaUnstaged   /\v^# %([ MARC][MD]|DM)\s.*$/hs=s+2 contains=GitaComment'
  execute 'syntax match GitaStaged     /\v^# [MADRC] \s.*$/hs=s+2 contains=GitaComment'
  execute 'syntax match GitaUntracked  /\v^# \?\?\s.*$/hs=s+2 contains=GitaComment'
  execute 'syntax match GitaIgnored    /\v^# !!\s.*$/hs=s+2 contains=GitaComment'
  execute 'syntax match GitaImportant  /\v^# AMEND/hs=s+2 contains=GitaComment'
  execute 'syntax match GitaComment    /\v^# On branch/ contained'
  execute 'syntax match GitaBranch     /\v^# On branch .*$/hs=s+12 contains=GitaComment'
  " github
  execute 'syntax keyword GitaGitHubKeyword close closes closed fix fixes fixed resolve resolves resolved'
  execute 'syntax match   GitaGitHubIssue   "\v%([^ /#]+/[^ /#]+#\d+|#\d+)"'
endfunction " }}}

" Assign constant variables
if !exists('s:const')
  let s:const = g:gita#ui#status#const
endif

let &cpo = s:save_cpo
unlet! s:save_cpo
"vim: stts=2 sw=2 smarttab et ai textwidth=0 fdm=marker
