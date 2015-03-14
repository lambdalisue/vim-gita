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

" vital modules (cached)
let s:Path          = gita#util#import('System.Filepath')
let s:Buffer        = gita#util#import('Vim.Buffer')
let s:BufferManager = gita#util#import('Vim.BufferManager')
let s:Cache         = gita#util#import('System.Cache.Simple')
let s:Git           = gita#util#import('VCS.Git')
let s:GitMisc       = gita#util#import('VCS.Git.Misc')

" common features
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
function! s:get_header_lines() abort " {{{
  let b = substitute(s:GitMisc.get_local_branch_name(), '\v^"|"$', '', 'g')
  let r = substitute(s:GitMisc.get_remote_branch_name(), '\v^"|"$', '', 'g')
  let o = s:GitMisc.count_commits_ahead_of_remote()
  let i = s:GitMisc.count_commits_behind_remote()

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

function! s:smart_map(lhs, rhs) abort " {{{
  " return {rhs} if the mapping is called on Git status line of status/commit
  " buffer. otherwise it return {lhs}
  if &filetype != s:const.status_filetype && &filetype != s:const.commit_filetype
    throw 'vim-gita: s:smart_map required to be executed on a proper buffer'
  endif
  let status_map = b:gita.get('status_map', {})
  let selected_line = getline('.')
  let selected_status = get(status_map, selected_line, {})
  return empty(selected_status) ? a:lhs : a:rhs
endfunction " }}}

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


" gita-status buffer
function! s:status_open(...) abort " {{{
  let options = extend({
        \ 'force_construction': 0,
        \}, get(a:000, 0, {}))
  let invoker_bufnum = bufnr('')
  " open or move to the gita-status buffer
  let manager = s:get_buffer_manager()
  let bufinfo = manager.open(s:const.status_bufname)
  if bufinfo.bufnr == -1
    call gita#util#error('vim-gita: failed to open a git status window')
    return
  endif

  if exists('b:gita') && !options.force_construction
    call b:gita.set('options', options)
    call b:gita.set('invoker_bufnum', invoker_bufnum)
    call b:gita.set('invoker_winnum', bufwinnr(invoker_bufnum))
    call s:status_update()
    return
  endif
  let b:gita = s:Cache.new()
  call b:gita.set('options', options)
  call b:gita.set('invoker_bufnum', invoker_bufnum)
  call b:gita.set('invoker_winnum', bufwinnr(invoker_bufnum))

  " construction
  setlocal buftype=nofile bufhidden=wipe noswapfile nobuflisted
  setlocal textwidth=0
  setlocal cursorline
  setlocal winfixheight
  execute 'setlocal filetype=' . s:const.status_filetype

  nnoremap <silent><buffer> <Plug>(gita-action-commit)      :<C-u>call <SID>status_action('commit')<CR>
  nnoremap <silent><buffer> <Plug>(gita-action-commit-amend):<C-u>call <SID>status_action('commit', 'amend')<CR>
  nnoremap <silent><buffer> <Plug>(gita-action-update)      :<C-u>call <SID>status_action('update')<CR>

  nnoremap <silent><buffer> <Plug>(gita-action-add)         :<C-u>call <SID>status_action('add')<CR>
  nnoremap <silent><buffer> <Plug>(gita-action-ADD)         :<C-u>call <SID>status_action('add', 'force')<CR>
  nnoremap <silent><buffer> <Plug>(gita-action-rm)          :<C-u>call <SID>status_action('rm')<CR>
  nnoremap <silent><buffer> <Plug>(gita-action-RM)          :<C-u>call <SID>status_action('rm', 'force')<CR>
  nnoremap <silent><buffer> <Plug>(gita-action-rm-cached)   :<C-u>call <SID>status_action('rm_cached')<CR>
  nnoremap <silent><buffer> <Plug>(gita-action-checkout)    :<C-u>call <SID>status_action('checkout')<CR>
  nnoremap <silent><buffer> <Plug>(gita-action-CHECKOUT)    :<C-u>call <SID>status_action('checkout', 'force')<CR>
  nnoremap <silent><buffer> <Plug>(gita-action-revert)      :<C-u>call <SID>status_action('revert')<CR>
  nnoremap <silent><buffer> <Plug>(gita-action-toggle)      :<C-u>call <SID>status_action('toggle')<CR>
  nnoremap <silent><buffer> <Plug>(gita-action-diff-split)  :<C-u>call <SID>status_action('diff', 'split')<CR>
  nnoremap <silent><buffer> <Plug>(gita-action-diff-vsplit) :<C-u>call <SID>status_action('diff', 'vsplit')<CR>
  nnoremap <silent><buffer> <Plug>(gita-action-open-edit)   :<C-u>call <SID>status_action('open', 'edit')<CR>
  nnoremap <silent><buffer> <Plug>(gita-action-open-split)  :<C-u>call <SID>status_action('open', 'split')<CR>
  nnoremap <silent><buffer> <Plug>(gita-action-open-vsplit) :<C-u>call <SID>status_action('open', 'vsplit')<CR>
  nnoremap <silent><buffer> <Plug>(gita-action-open-left)   :<C-u>call <SID>status_action('open', 'left')<CR>
  nnoremap <silent><buffer> <Plug>(gita-action-open-right)  :<C-u>call <SID>status_action('open', 'right')<CR>
  nnoremap <silent><buffer> <Plug>(gita-action-open-above)  :<C-u>call <SID>status_action('open', 'above')<CR>
  nnoremap <silent><buffer> <Plug>(gita-action-open-below)  :<C-u>call <SID>status_action('open', 'below')<CR>
  nnoremap <silent><buffer> <Plug>(gita-action-open-tabnew) :<C-u>call <SID>status_action('open', 'tabnew')<CR>

  vnoremap <silent><buffer> <Plug>(gita-action-add)         :call <SID>status_action('add')<CR>
  vnoremap <silent><buffer> <Plug>(gita-action-ADD)         :call <SID>status_action('add', 'force')<CR>
  vnoremap <silent><buffer> <Plug>(gita-action-rm)          :call <SID>status_action('rm')<CR>
  vnoremap <silent><buffer> <Plug>(gita-action-RM)          :call <SID>status_action('rm', 'force')<CR>
  vnoremap <silent><buffer> <Plug>(gita-action-rm-cached)   :call <SID>status_action('rm_cached')<CR>
  vnoremap <silent><buffer> <Plug>(gita-action-checkout)    :call <SID>status_action('checkout')<CR>
  vnoremap <silent><buffer> <Plug>(gita-action-CHECKOUT)    :call <SID>status_action('checkout', 'force')<CR>
  vnoremap <silent><buffer> <Plug>(gita-action-revert)      :call <SID>status_action('revert')<CR>
  vnoremap <silent><buffer> <Plug>(gita-action-toggle)      :call <SID>status_action('toggle')<CR>

  if get(g:, 'gita#interface#enable_default_keymaps', 1)
    nmap <buffer>       q      :<C-u>q<CR>
    nmap <buffer>       <C-l>  <Plug>(gita-action-update)
    nmap <buffer>       cc     <Plug>(gita-action-commit)
    nmap <buffer>       ca     <Plug>(gita-action-commit-amend)
    nmap <buffer><expr> -a     <SID>smart_map('-a', '<Plug>(gita-action-add)')
    nmap <buffer><expr> -A     <SID>smart_map('-A', '<Plug>(gita-action-ADD)')
    nmap <buffer><expr> -r     <SID>smart_map('-r', '<Plug>(gita-action-rm)')
    nmap <buffer><expr> -R     <SID>smart_map('-R', '<Plug>(gita-action-RM)')
    nmap <buffer><expr> -h     <SID>smart_map('-h', '<Plug>(gita-action-rm-cached)')
    nmap <buffer><expr> -c     <SID>smart_map('-c', '<Plug>(gita-action-checkout)')
    nmap <buffer><expr> -C     <SID>smart_map('-C', '<Plug>(gita-action-CHECKOUT)')
    nmap <buffer><expr> -=     <SID>smart_map('-=', '<Plug>(gita-action-revert)')
    nmap <buffer><expr> --     <SID>smart_map('--', '<Plug>(gita-action-toggle)')
    nmap <buffer><expr> <CR>   <SID>smart_map('<CR>', '<Plug>(gita-action-open-edit)')
    nmap <buffer><expr> <S-CR> <SID>smart_map('<S-CR>', '<Plug>(gita-action-diff-vsplit)')
    nmap <buffer><expr> e      <SID>smart_map('e', '<Plug>(gita-action-open-edit)')
    nmap <buffer><expr> E      <SID>smart_map('E', '<Plug>(gita-action-open-vsplit)')
    nmap <buffer><expr> <C-e>  <SID>smart_map('<C-e>', '<Plug>(gita-action-open-split)')
    nmap <buffer><expr> d      <SID>smart_map('d', '<Plug>(gita-action-diff-split)')
    nmap <buffer><expr> D      <SID>smart_map('D', '<Plug>(gita-action-diff-vsplit)')
    nmap <buffer><expr> <C-d>  <SID>smart_map('<C-d>', '<Plug>(gita-action-diff-split)')

    vmap <buffer><expr> -a     <SID>smart_map('-a', '<Plug>(gita-action-add)')
    vmap <buffer><expr> -r     <SID>smart_map('-r', '<Plug>(gita-action-rm)')
    vmap <buffer><expr> -c     <SID>smart_map('-c', '<Plug>(gita-action-rm-cached)')
    vmap <buffer><expr> -C     <SID>smart_map('-C', '<Plug>(gita-action-checkout)')
    vmap <buffer><expr> -R     <SID>smart_map('-R', '<Plug>(gita-action-revert)')
    vmap <buffer><expr> --     <SID>smart_map('--', '<Plug>(gita-action-toggle)')
  endif

  " automatically focus invoker when the buffer is closed
  autocmd! * <buffer>
  autocmd WinLeave <buffer> call s:invoker_focus(b:gita)

  " update contents
  call s:status_update()
endfunction " }}}
function! s:status_update() abort " {{{
  if &filetype != s:const.status_filetype
    throw 'vim-gita: s:status_update required to be executed on a proper buffer'
  endif

  let status = s:GitMisc.get_parsed_status()
  if empty(status)
    " the cwd is not inside of git work tree
    let manager = s:get_buffer_manager()
    call manager.close(s:const.status_bufname)
    return
  elseif empty(status.all)
    let buflines = gita#util#flatten([
          \ s:get_header_lines(),
          \ 'nothing to commit (working directory clean)',
          \])
    let status_map = {}
  else
    let buflines = s:get_header_lines()
    let status_map = {}
    for s in status.all
      let status_line = s:get_status_line(s)
      let status_map[status_line] = s
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

  call b:gita.set('status_map', status_map)
  call b:gita.set('status', status)
  redraw
endfunction " }}}
function! s:status_action(name, ...) abort " {{{
  if &filetype != s:const.status_filetype
    throw 'vim-gita: s:status_action required to be executed on a proper buffer'
  endif
  let opener = get(g:gita#interface#opener_aliases, get(a:000, 0, ''), '')
  let status_map = b:gita.get('status_map', {})
  let selected_line = getline('.')
  let selected_status = get(status_map, selected_line, {})
  if empty(selected_status) && a:name !~# '\v%(update|commit)'
    " the action is executed on invalid line so just do nothing
    return 0
  endif
  let fname = printf('s:status_action_%s', a:name)
  call call(fname, [selected_status, opener])
  return 1
endfunction " }}}
function! s:status_action_commit(status, opener) abort " {{{
  let options = {
        \ 'force_construction': 1,
        \ 'amend': a:opener ==# 'amend',
        \}
  call s:commit_open(options)
endfunction " }}}
function! s:status_action_update(status, opener) abort " {{{
  call s:status_update()
  redraw!
endfunction " }}}
function! s:status_action_add(status, opener) abort " {{{
  let force = a:opener ==# 'force' ? '--force' : ''
  if a:status.is_ignored && !strlen(force)
    call gita#util#warn('ignored file could not be added. use <Plug>(gita-action-ADD) to add')
    return
  elseif !a:status.is_unstaged && !a:status.is_untracked
    call gita#util#info('no changes are existing on the file (working tree is clean)')
    return
  endif
  call gita#action#add([force, '--', a:status.path])
  call s:status_update()
endfunction " }}}
function! s:status_action_rm(status, opener) abort " {{{
  let force = a:opener ==# 'force' ? '--force' : ''
  if a:status.is_ignored && !strlen(force)
    " TODO is this true?
    call gita#util#warn('ignored file could not be removed. use <Plug>(gita-action-RM) to add')
    return
  elseif !a:status.is_unstaged
    call gita#util#info('no changes are existing on the file (working tree is clean)')
    return
  endif
  call gita#action#rm([force, '--', a:status.path])
  call s:status_update()
endfunction " }}}
function! s:status_action_rm_cached(status, opener) abort " {{{
  if !a:status.is_staged
    call gita#util#info('no changes are existing on the index (index is clean)')
    return
  endif
  call gita#action#rm(['--cached', '--', a:status.path])
  call s:status_update()
endfunction " }}}
function! s:status_action_checkout(status, opener) abort " {{{
  let force = a:opener ==# 'force' ? '--force' : ''
  if a:status.is_conflicted
    call gita#util#error(
          \ 'the behavior of checking out a conflicted file is not defined. let me know if you know the proper behavior.',
          \ 'The behavior is not defined')
    return
  elseif a:status.is_ignored
    call gita#util#error(
          \ 'the behavior of checking out an ignored file is not defined. let me know if you know the proper behavior.',
          \ 'The behavior is not defined')
    return
  elseif a:status.is_unstaged && !strlen(force)
    call gita#util#warn('locally changed file could not be checked out. use <Plug>(gita-action-CHECKOUT) to checkout')
    return
  endif
  call gita#action#checkout([force, 'HEAD', '--', a:status.path])
  call s:status_update()
endfunction " }}}
function! s:status_action_revert(status, opener) abort " {{{
  " remove untracked file or checkout HEAD file to discard the local changes
  if a:status.is_conflicted || a:status.is_ignored
    call gita#util#warn(
          \ 'the behavior of reverting confliced or ignored file is not defined.',
          \ 'The behavior is not defined')
    return
  elseif a:status.is_untracked
    call gita#util#warn(
          \ 'This operation will remove the untracked file and could not be reverted',
          \ 'CAUTION: The operation could not be reverted',
          \)
    let a = gita#util#asktf('Are you sure that you want to remove the untracked file?')
    if a
      call delete(a:status.path)
    endif
  else
    call gita#util#warn(
          \ 'This operation will discard the local changes on the file and could not be reverted',
          \ 'CAUTION: The operation could not be reverted',
          \)
    let a = gita#util#asktf('Are you sure that you want to discard the local changes on the file?')
    if a
      call s:status_action_checkout(a:status, 'force')
    endif
  endif
  call s:status_update()
endfunction " }}}
function! s:status_action_toggle(status, opener) abort " {{{
  if a:status.is_conflicted || a:status.is_ignored
    call gita#util#warn(
          \ 'the behavior of toggling confliced or ignored file is not defined.',
          \ 'The behavior is not defined')
    return
  elseif a:status.is_unstaged
    if a:status.worktree == 'D'
      call s:status_action_rm(a:status, a:opener)
    else
      call s:status_action_add(a:status, a:opener)
    endif
  elseif a:status.is_untracked
      call s:status_action_add(a:status, a:opener)
  else
      call s:status_action_rm_cached(a:status, a:opener)
  endif
endfunction " }}}
function! s:status_action_open(status, opener) abort " {{{
  let invoker_winnum = s:invoker_get_winnum(b:gita)
  if invoker_winnum != -1
    silent execute invoker_winnum . 'wincmd w'
  else
    silent execute 'wincmd p'
  endif
  " open the selected status file
  let path = get(a:status, 'path2', a:status.path)
  call s:Buffer.open(path, a:opener)
endfunction " }}}
function! s:status_action_diff(status, opener) abort " {{{
  call gita#util#error('the action has not been implemented yet.', 'Not implemented error:')
endfunction " }}}

" gita-commit buffer
function! s:commit_open(...) abort " {{{
  let options = extend({
        \ 'force_construction': 0,
        \ 'amend': 0,
        \}, get(a:000, 0, {}))
  let invoker_bufnum = bufnr('')
  " open or move to the gita-commit buffer
  let manager = s:get_buffer_manager()
  let bufinfo = manager.open(s:const.commit_bufname)
  if bufinfo.bufnr == -1
    call gita#util#error('vim-gita: failed to open a git commit window')
    return
  endif

  if exists('b:gita') && !options.force_construction
    call b:gita.set('options', options)
    call b:gita.set('invoker_bufnum', invoker_bufnum)
    call b:gita.set('invoker_winnum', bufwinnr(invoker_bufnum))
    call s:commit_update()
    return
  endif
  let b:gita = s:Cache.new()
  call b:gita.set('options', options)
  call b:gita.set('invoker_bufnum', invoker_bufnum)
  call b:gita.set('invoker_winnum', bufwinnr(invoker_bufnum))

  " construction
  setlocal buftype=acwrite bufhidden=wipe noswapfile nobuflisted
  setlocal winfixheight
  execute 'setlocal filetype=' . s:const.commit_filetype

  nnoremap <silent><buffer> <Plug>(gita-action-status)      :<C-u>call <SID>commit_action('status')<CR>
  nnoremap <silent><buffer> <Plug>(gita-action-diff-split)  :<C-u>call <SID>commit_action('diff', 'split')<CR>
  nnoremap <silent><buffer> <Plug>(gita-action-diff-vsplit) :<C-u>call <SID>commit_action('diff', 'vsplit')<CR>
  nnoremap <silent><buffer> <Plug>(gita-action-open-edit)   :<C-u>call <SID>commit_action('open', 'edit')<CR>
  nnoremap <silent><buffer> <Plug>(gita-action-open-split)  :<C-u>call <SID>commit_action('open', 'split')<CR>
  nnoremap <silent><buffer> <Plug>(gita-action-open-vsplit) :<C-u>call <SID>commit_action('open', 'vsplit')<CR>
  nnoremap <silent><buffer> <Plug>(gita-action-open-left)   :<C-u>call <SID>commit_action('open', 'left')<CR>
  nnoremap <silent><buffer> <Plug>(gita-action-open-right)  :<C-u>call <SID>commit_action('open', 'right')<CR>
  nnoremap <silent><buffer> <Plug>(gita-action-open-above)  :<C-u>call <SID>commit_action('open', 'above')<CR>
  nnoremap <silent><buffer> <Plug>(gita-action-open-below)  :<C-u>call <SID>commit_action('open', 'below')<CR>
  nnoremap <silent><buffer> <Plug>(gita-action-open-tabnew) :<C-u>call <SID>commit_action('open', 'tabnew')<CR>

  if get(g:, 'gita#interface#enable_default_keymaps', 1)
    nmap <buffer>       q      :<C-u>q<CR>
    nmap <buffer>       cc     <Plug>(gita-action-status)
    nmap <buffer>       ca     <Plug>(gita-action-status)

    nmap <buffer><expr> <CR>   <SID>smart_map('<CR>', '<Plug>(gita-action-open-edit)')
    nmap <buffer><expr> <S-CR> <SID>smart_map('<S-CR>', '<Plug>(gita-action-diff-vsplit)')
    nmap <buffer><expr> e      <SID>smart_map('e', '<Plug>(gita-action-open-edit)')
    nmap <buffer><expr> E      <SID>smart_map('E', '<Plug>(gita-action-open-vsplit)')
    nmap <buffer><expr> <C-e>  <SID>smart_map('<C-e>', '<Plug>(gita-action-open-split)')
    nmap <buffer><expr> d      <SID>smart_map('d', '<Plug>(gita-action-diff-split)')
    nmap <buffer><expr> D      <SID>smart_map('D', '<Plug>(gita-action-diff-vsplit)')
    nmap <buffer><expr> <C-d>  <SID>smart_map('<C-d>', '<Plug>(gita-action-diff-split)')
  endif

  " automatically focus invoker when the buffer is closed
  autocmd! * <buffer>
  autocmd BufWriteCmd <buffer> call s:commit_do_write(expand("<amatch>"), b:gita)
  autocmd BufWinLeave <buffer> call s:commit_do_commit(b:gita)
  autocmd WinLeave <buffer> call s:invoker_focus(b:gita)

  " update contents
  call s:commit_update()
endfunction " }}}
function! s:commit_update() abort " {{{
  if &filetype != s:const.commit_filetype
    throw 'vim-gita: s:commit_update required to be executed on a proper buffer'
  endif
  let options = b:gita.get('options', {})

  " update contents
  let status = s:GitMisc.get_parsed_status()
  if empty(status)
    bw!
    return
  endif

  " create commit comments
  let buflines = s:get_header_lines()
  let status_map = {}
  for s in status.all
    let status_line = printf('# %s', s:get_status_line(s))
    let status_map[status_line] = s
    call add(buflines, status_line)
  endfor

  " create default commit message
  if empty(status.staged)
    let buflines = ['no changes added to commit'] + buflines
  elseif get(options, 'amend', 0)
    let commitmsg = s:GitMisc.get_last_commit_message() 
    let buflines = split(join(commitmsg, "\n"), "\n") + buflines
  else
    let buflines = [''] + buflines
  endif

  " remove the entire content and rewrite the buflines
  setlocal modifiable
  let save_undolevels = &undolevels
  setlocal undolevels=-1
  silent %delete _
  call setline(1, buflines)
  let &undolevels = save_undolevels
  setlocal nomodified
  " select the first line
  call setpos('.', [bufnr(''), 1, 1, 0])

  call b:gita.set('status_map', status_map)
  call b:gita.set('status', status)
  redraw
endfunction " }}}
function! s:commit_do_write(filename, gita) abort " {{{
  if &filetype != s:const.commit_filetype
    throw 'vim-gita: s:commit_do_write required to be executed on a proper buffer'
  endif
  if a:filename != expand('%:p')
    " a new filename is given. save the content to the new file
    execute 'w' . (v:cmdbang ? '!' : '') fnameescape(v:cmdarg) fnameescape(a:filename)
    return
  endif
  setlocal nomodified
endfunction " }}}
function! s:commit_do_commit(gita) abort " {{{
  if &filetype != s:const.commit_filetype
    throw 'vim-gita: s:commit_do_commit required to be executed on a proper buffer'
  endif
  let status = a:gita.get('status', {})
  if empty(status) || empty(status.staged)
    return
  endif
  " get comment removed content
  let contents = filter(copy(getline(1, '$')), 'v:val !~$ "^#"')
  " check if commit should be executed
  if &modified || join(contents, "") =~# '\v^\s*$'
    call gita#util#warn('Commiting the changes has canceled.')
    return
  endif
  " save comment removed content to a tempfile
  let filename = tempname()
  call writefile(contents, filename)
  let args = ['--file', filename]
  if get(a:gita.get('options'), 'amend', 0)
    let args = args + ['--amend']
  endif
  let result = call(s:Git.commit, [args], s:Git)
  call delete(filename)
  if result.status == 0
    call gita#util#info(result.stdout, 'The changes has been commited')
  else
    call gita#util#error(result.stdout, 'An exception has occur')
  endif
endfunction " }}}
function! s:commit_action(name, ...) abort " {{{
  if &filetype != s:const.commit_filetype
    throw 'vim-gita: s:status_action required to be executed on a proper buffer'
  endif
  let opener = get(g:gita#interface#opener_aliases, get(a:000, 0, ''), '')
  let status_map = b:gita.get('status_map', {})
  let selected_line = getline('.')
  let selected_status = get(status_map, selected_line, {})
  if empty(selected_status) && a:name !~# '\v%(status)'
    " the action is executed on invalid line so just do nothing
    return
  endif
  if a:name =~# '\v%(open|diff)'
    let fname = printf('s:status_action_%s', a:name)
  else
    let fname = printf('s:commit_action_%s', a:name)
  endif
  call call(fname, [selected_status, opener])
endfunction " }}}
function! s:commit_action_status(status, opener) abort " {{{
  let options = {
        \ 'force_construction': 1,
        \}
  call s:status_open(options)
endfunction " }}}

" Public
function! gita#interface#smart_map(lhs, rhs) abort " {{{
  if &filetype != s:const.status_filetype & &filetype != s:const.commit_filetype
    throw 'vim-gita: s:smartmap required to be executed on a proper buffer'
  endif
  if !exists('b:gita')
    return a:lhs
  endif
  let status_map = b:gita.get('status_map', {})
  let selected_line = getline('.')
  let selected_status = get(status_map, selected_line, {})
  if empty(selected_status) && a:name !~# '\v%(update|commit)'
    " the action is executed on invalid line so just do nothing
    return 0
  endif
endfunction " }}}

function! gita#interface#status_open(...) abort " {{{
  call call('s:status_open', a:000)
endfunction " }}}
function! gita#interface#status_update() abort " {{{
  let bufnum = bufnr(s:const.status_bufname)
  let winnum = bufwinnr(bufnum)
  if winnum == -1
    call gita#util#warn(
          \ 'use "gita#interface#open_status({options})" prier to this method.',
          \ 'vim-gita: "gita-status" buffer is not opened.',
          \)
    return
  endif

  let saved_bufnum = bufnr('')
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

function! gita#interface#define_highlights() abort " {{{
  highlight default link GitaComment    Comment
  highlight default link GitaConflicted ErrorMsg
  highlight default link GitaUnstaged   WarningMsg
  highlight default link GitaStaged     Question
  highlight default link GitaUntracked  WarningMsg
  highlight default link GitaIgnored    Question
  highlight default link GitaBranch     Title
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

