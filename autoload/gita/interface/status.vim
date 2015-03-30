"******************************************************************************
" vim-gita interface/status
"
" Author:   Alisue <lambdalisue@hashnote.net>
" URL:      http://hashnote.net/
" License:  MIT license
" (C) 2015, Alisue, hashnote.net
"******************************************************************************
let s:save_cpo = &cpo
set cpo&vim

let s:const = {}
let s:const.bufname  = has('unix') ? 'gita:status' : 'gita_status'
let s:const.filetype = 'gita-status'

let s:Prelude = gita#util#import('Prelude')
let s:List = gita#util#import('Data.List')
let s:Conflict = gita#util#import('VCS.Git.Conflict')

function! s:ensure_list(x) abort " {{{
  return s:Prelude.is_list(a:x) ? a:x : [a:x]
endfunction " }}}
function! s:get_gita(...) abort " {{{
  let gita = call('gita#get', a:000)
  let gita.interface = get(gita, 'interface', {})
  let gita.interface.status = get(gita.interface, 'status', {})
  return gita
endfunction " }}}
function! s:get_selected_status() abort " {{{
  let gita = s:get_gita()
  let statuses_map = get(gita.interface.status, 'statuses_map', {})
  let selected_line = getline('.')
  return get(statuses_map, selected_line, {})
endfunction " }}}
function! s:get_selected_statuses() abort " {{{
  let gita = s:get_gita()
  let statuses_map = get(gita.interface.status, 'statuses_map', {})
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
function! s:get_help(about) abort " {{{
  let varname = printf('_help_%s', a:about)
  if get(b:, varname, 0)
    return gita#util#interface_get_help(a:about)
  else
    return []
  endif
endfunction " }}}
function! s:smart_map(lhs, rhs) abort " {{{
  return empty(s:get_selected_status()) ? a:lhs : a:rhs
endfunction " }}}
function! s:validate_filetype(name) abort " {{{
  if &filetype !=# s:const.filetype
    call gita#util#error(
          \ printf('%s required to be called on %s buffer', a:name, s:const.bufname),
          \ 'FileType miss match',
          \)
    return 1
  endif
  return 0
endfunction " }}}
function! s:validate_status_add(status, options) abort " {{{
  if a:status.is_unstaged || a:status.is_untracked
    return 0
  elseif a:status.is_ignored && get(a:options, 'force', 0)
    return 0
  elseif a:status.is_ignored
    call gita#util#info(printf(
          \ 'An ignored file "%s" cannot be added. Use <Plug>(gita-action-ADD) instead.',
          \ a:status.path,
          \))
    return 1
  elseif a:status.is_conflicted
    if a:status.sign ==# 'DD'
      call gita#util#error(printf(
            \ 'A both deleted conflict file "%s" cannot be added. Use <Plug>(gita-action-rm) instead.',
            \ a:status.path,
            \))
      return 1
    else
      return 0
    endif
  else
    call gita#util#info(printf(
          \ 'No changes of "%s" exist on working tree.',
          \ a:status.path,
          \))
    return 1
  endif
endfunction " }}}
function! s:validate_status_rm(status, options) abort " {{{
  if (a:status.is_staged || a:status.is_unstaged) && a:status.worktree ==# 'D'
    " already removed from filesystem
    return 0
  elseif a:status.is_staged || a:status.is_unstaged
    if get(a:options, 'force', 0)
      return 0
    else
      call gita#util#info(printf(
            \ 'A file "%s" has changes and cannot be deleted. Use <Plug>(gita-action-RM) instead.',
            \ a:status.path,
            \))
      return 1
    endif
  elseif a:status.is_untracked || a:status.is_ignored
    call gita#util#info(printf(
          \ 'An untracked/ignored file "%s" cannot be deleted.',
          \ a:status.path,
          \))
    return 1
  elseif a:status.is_conflicted
    if a:status.sign ==# 'AU'
      call gita#util#error(printf(
            \ 'A added by us conflict file "%s" cannot be deleted. Use <Plug>(git-action-add) instead.',
            \ a:status.path,
            \))
      return 1
    elseif a:status.sign ==# 'UA'
      call gita#util#error(printf(
            \ 'A added by them conflict file "%s" cannot be deleted. Use <Plug>(git-action-add) instead.',
            \ a:status.path,
            \))
      return 1
    elseif a:status.sign ==# 'AA'
      call gita#util#error(printf(
            \ 'A both added conflict file "%s" cannot be deleted. Use <Plug>(git-action-add) instead.',
            \ a:status.path,
            \))
      return 1
    elseif a:status.sign ==# 'UU'
      call gita#util#error(printf(
            \ 'A both modified conflict file "%s" cannot be deleted. Use <Plug>(git-action-add) instead.',
            \ a:status.path,
            \))
      return 1
    else
      return 0
    endif
  else
    " it should not be called
    call gita#util#error(printf(
          \ 'An unexpected pattern "%s" is called for "rm". Report it as an issue on GitHub.',
          \ a:status.sign,
          \))
    return 1
  endif
endfunction " }}}
function! s:validate_status_reset(status, options) abort " {{{
  if a:status.is_staged
    return 0
  elseif a:status.is_untracked || a:status.is_ignored
    call gita#util#info(printf(
          \ 'An untracked/ignored file "%s" cannot be reset.',
          \ a:status.path,
          \))
    return 1
  elseif a:status.is_conflicted
    call gita#util#error(printf(
          \ 'A conflicted file "%s" cannot be reset. ',
          \ a:status.path,
          \))
    return 1
  else
    call gita#util#info(printf(
          \ 'No changes of "%s" exist on index.',
          \ a:status.path,
          \))
    return 1
  endif
endfunction " }}}
function! s:validate_status_checkout(status, options) abort " {{{
  if a:status.is_unstaged
    if get(a:options, 'force', 0)
      return 0
    else
      call gita#util#info(printf(
            \ 'A file "%s" has unstaged changes. Use <Plug>(gita-action-CHECKOUT) instead.',
            \ a:status.path,
            \))
      return 1
    endif
  elseif a:status.is_untracked || a:status.is_ignored
    call gita#util#info(printf(
          \ 'An untracked/ignored file "%s" cannot be checked out.',
          \ a:status.path,
          \))
    return 1
  elseif a:status.is_conflicted
    call gita#util#error(printf(
          \ 'A conflicted file "%s" cannot be checked out. Use <Plug>(gita-action-ours) or <Plug>(gita-action-theirs) instead.',
          \ a:status.path,
          \))
    return 1
  else
    return 0
  endif
endfunction " }}}
function! s:validate_status_ours(status, options) abort " {{{
  if !a:status.is_conflicted
    call gita#util#info(printf(
          \ 'No ours version of a non conflicted file "%s" is available. Use <Plug>(gita-action-checkout) instead.',
          \ a:status.path,
          \))
    return 1
  else
    if a:status.sign ==# 'DD'
      call gita#util#info(printf(
            \ 'No ours version of a both deleted conflict file "%s" is available. Use <Plug>(gita-action-rm) instead.',
            \ a:status.path,
            \))
      return 1
    elseif a:status.sign ==# 'DU'
      call gita#util#info(printf(
            \ 'No ours version of a deleted by us conflict file "%s" is available. Use <Plug>(gita-action-add) or <Plug>(gita-action-rm) instead.',
            \ a:status.path,
            \))
      return 1
    else
      return 0
    endif
  endif
endfunction " }}}
function! s:validate_status_theirs(status, options) abort " {{{
  if !a:status.is_conflicted
    call gita#util#info(printf(
          \ 'No theirs version of a non conflicted file "%s" is available. Use <Plug>(gita-action-checkout) instead.',
          \ a:status.path,
          \))
    return 1
  else
    if a:status.sign ==# 'DD'
      call gita#util#info(printf(
            \ 'No theirs version of a both deleted conflict file "%s" is available. Use <Plug>(gita-action-rm) instead.',
            \ a:status.path,
            \))
      return 1
    elseif a:status.sign ==# 'UD'
      call gita#util#info(printf(
            \ 'No theirs version of a deleted by them conflict file "%s" is available. Use <Plug>(gita-action-add) or <Plug>(gita-action-rm) instead.',
            \ a:status.path,
            \))
      return 1
    else
      return 0
    endif
  endif
endfunction " }}}
function! s:validate_status_conflict(status, options) abort " {{{
  if !a:status.is_conflicted
    call gita#util#info(printf(
          \ 'A conflict action cannot be performed on a non conflicted file "%s".',
          \ a:status.path,
          \))
    return 1
  else
    if a:status.sign ==# 'DD'
      call gita#util#info(printf(
            \ 'A conflic action cannot be performed on a both deleted conflict file "%s".',
            \ a:status.path,
            \))
      return 1
    elseif a:status.sign ==# 'DU'
      call gita#util#info(printf(
            \ 'A conflic action cannot be performed on a deleted by us conflict file "%s".',
            \ a:status.path,
            \))
      return 1
    elseif a:status.sign ==# 'UD'
      call gita#util#info(printf(
            \ 'A conflic action cannot be performed on a deleted by them conflict file "%s".',
            \ a:status.path,
            \))
      return 1
    else
      return 0
    endif
  endif
endfunction " }}}

function! s:action(name, ...) abort " {{{
  let multiple = get(a:000, 0, 0)
  let options  = get(a:000, 1, {})
  if s:Prelude.is_dict(multiple)
    let options = multiple
    unlet! multiple | let multiple = 0
  endif
  let options = extend(deepcopy(b:_options), options)

  if multiple
    let statuses = s:get_selected_statuses()
    let args = [statuses, options]
  else
    let status = s:get_selected_status()
    let args = [status, options]
  endif

  call call(printf('s:action_%s', a:name), args)
endfunction " }}}
function! s:action_help(status, options) abort " {{{
  let varname = printf('_help_%s', a:options.about)
  let b:[varname] = !get(b:, varname, 0)
  call s:update(a:options)
endfunction " }}}
function! s:action_update(status, options) abort " {{{
  call s:update(a:options)
  redraw!
endfunction " }}}
function! s:action_open_commit(status, options) abort " {{{
  call gita#interface#commit#open(a:options)
endfunction " }}}
function! s:action_open(status, options) abort " {{{
  let options = extend({
        \ 'opener': 'edit',
        \}, a:options)
  if options.opener ==# 'select'
    let winnum = gita#util#choosewin()
    let opener = 'edit'
  else
    let opener = options.opener
    call gita#util#invoker_focus()
  endif
  call gita#util#buffer_open(get(a:status, 'path2', a:status.path), opener)
endfunction " }}}
function! s:action_diff_open(status, options) abort " {{{
  let commit = gita#util#ask('Checkout from: ', 'HEAD')
  if strlen(commit) == 0
    redraw || call gita#util#warn('No valid commit was selected. The operation is canceled.')
    return
  endif
  let options = extend({
        \ 'opener': 'edit',
        \}, a:options)
  if options.opener ==# 'select'
    let winnum = gita#util#choosewin()
    let options.opener = 'edit'
  else
    call gita#util#invoker_focus()
  endif
  call gita#interface#diff#open(a:status, commit, options)
endfunction " }}}
function! s:action_diff_compare(status, options) abort " {{{
  let commit = gita#util#ask('Checkout from: ', 'HEAD')
  if strlen(commit) == 0
    redraw || call gita#util#warn('No valid commit was selected. The operation is canceled.')
    return
  endif
  let options = extend({
        \ 'opener': 'tabnew',
        \}, a:options)
  if options.opener ==# 'select'
    let winnum = gita#util#choosewin()
    let options.opener = 'edit'
  else
    call gita#util#invoker_focus()
  endif
  call gita#interface#diff#compare(a:status, commit, options)
endfunction " }}}
function! s:action_conflict2(status, options) abort " {{{
  let options = extend({
        \ 'opener': 'edit',
        \}, a:options)
  if s:validate_status_conflict(a:status, options)
    return
  endif
  if options.opener ==# 'select'
    let winnum = gita#util#choosewin()
    let opener = 'edit'
  else
    let opener = options.opener
    call gita#util#invoker_focus()
  endif
  call gita#interface#conflict#open2(a:status, options)
endfunction " }}}
function! s:action_conflict3(status, options) abort " {{{
  let options = extend({
        \ 'opener': 'edit',
        \}, a:options)
  if s:validate_status_conflict(a:status, options)
    return
  endif
  if options.opener ==# 'select'
    let winnum = gita#util#choosewin()
    let opener = 'edit'
  else
    let opener = options.opener
    call gita#util#invoker_focus()
  endif
  call gita#interface#conflict#open3(a:status, options)
endfunction " }}}
function! s:action_add(statuses, options) abort " {{{
  let statuses = s:ensure_list(a:statuses)
  let options = extend({ 'force': 0 }, a:options)
  let valid_statuses = []
  for status in statuses
    if s:validate_status_add(status, options)
      continue
    endif
    call add(valid_statuses, status)
  endfor
  if empty(valid_statuses)
    if !get(options, 'ignore_empty_warning', 0)
      call gita#util#warn(
            \ 'No valid files were selected for add action',
            \)
    endif
    return
  endif
  let result = s:get_gita().git.add(options, map(valid_statuses, 'v:val.path'))
  if result.status
    call gita#util#error(
          \ result.stdout,
          \ printf('Fail: %s', join(result.args)),
          \)
  else
    call gita#util#doautocmd('add-post')
  endif
  call s:update()
endfunction " }}}
function! s:action_rm(statuses, options) abort " {{{
  let statuses = s:ensure_list(a:statuses)
  let options = extend({ 'force': 0 }, a:options)
  let valid_statuses = []
  for status in statuses
    if s:validate_status_rm(status, options)
      continue
    endif
    call add(valid_statuses, status)
  endfor
  if empty(valid_statuses)
    if !get(options, 'ignore_empty_warning', 0)
      call gita#util#warn(
            \ 'No valid files were selected for rm action',
            \)
    endif
    return
  endif
  let result = s:get_gita().git.rm(options, map(valid_statuses, 'v:val.path'))
  if result.status
    call gita#util#error(
          \ result.stdout,
          \ printf('Fail: %s', join(result.args)),
          \)
  else
    call gita#util#doautocmd('rm-post')
  endif
  call s:update()
endfunction " }}}
function! s:action_reset(statuses, options) abort " {{{
  let statuses = s:ensure_list(a:statuses)
  let options = extend({
        \   'quiet': 1,
        \ }, a:options)
  let valid_statuses = []
  for status in statuses
    if s:validate_status_reset(status, options)
      continue
    endif
    call add(valid_statuses, status)
  endfor
  if empty(valid_statuses)
    if !get(options, 'ignore_empty_warning', 0)
      call gita#util#warn(
            \ 'No valid files were selected for reset action',
            \)
    endif
    return
  endif
  let result = s:get_gita().git.reset(options, '', map(valid_statuses, 'v:val.path'))
  if result.status
    call gita#util#error(
          \ result.stdout,
          \ printf('Fail: %s', join(result.args)),
          \)
  else
    call gita#util#doautocmd('reset-post')
  endif
  call s:update()
endfunction " }}}
function! s:action_checkout(statuses, options) abort " {{{
  let statuses = s:ensure_list(a:statuses)
  let options = extend({}, a:options)
  if !has_key(options, 'commit')
    let commit = gita#util#ask('Checkout from: ', 'INDEX')
    if strlen(commit) == 0
      redraw || call gita#util#warn('No valid commit was selected. The operation is canceled.')
      return
    endif
  else
    let commit = options.commit
  endif
  let commit = commit ==# 'INDEX' ? '' : commit
  let valid_statuses = []
  for status in statuses
    if s:validate_status_checkout(status, options)
      continue
    endif
    call add(valid_statuses, status)
  endfor
  if empty(valid_statuses)
    if !get(options, 'ignore_empty_warning', 0)
      call gita#util#warn(
            \ 'No valid files were selected for checkout action',
            \)
    endif
    return
  endif
  let result = s:get_gita().git.checkout(options, commit, map(valid_statuses, 'v:val.path'))
  if result.status == 0
    call gita#util#doautocmd('checkout-post')
  else
    call gita#util#error(
          \ result.stdout,
          \ printf('Fail: %s', join(result.args)),
          \)
  endif
  call s:update()
endfunction " }}}
function! s:action_ours(statuses, options) abort " {{{
  let statuses = s:ensure_list(a:statuses)
  let options = extend({}, a:options)
  let options.ours = 1
  let valid_statuses = []
  for status in statuses
    if s:validate_status_ours(status, options)
      continue
    endif
    call add(valid_statuses, status)
  endfor
  if empty(valid_statuses)
    if !get(options, 'ignore_empty_warning', 0)
      call gita#util#warn(
            \ 'No valid files were selected for ours action',
            \)
    endif
    return
  endif
  let result = s:get_gita().git.checkout(options, '', map(valid_statuses, 'v:val.path'))
  if result.status == 0
    call gita#util#doautocmd('checkout-post')
  else
    call gita#util#error(
          \ result.stdout,
          \ printf('Fail: %s', join(result.args)),
          \)
  endif
  call s:update()
endfunction " }}}
function! s:action_theirs(statuses, options) abort " {{{
  let statuses = s:ensure_list(a:statuses)
  let options = extend({}, a:options)
  let options.theirs = 1
  let valid_statuses = []
  for status in statuses
    if s:validate_status_theirs(status, options)
      continue
    endif
    call add(valid_statuses, status)
  endfor
  if empty(valid_statuses)
    if !get(options, 'ignore_empty_warning', 0)
      call gita#util#warn(
            \ 'No valid files were selected for ours action',
            \)
    endif
    return
  endif
  let result = s:get_gita().git.checkout(options, '', map(valid_statuses, 'v:val.path'))
  if result.status == 0
    call gita#util#doautocmd('checkout-post')
  else
    call gita#util#error(
          \ result.stdout,
          \ printf('Fail: %s', join(result.args)),
          \)
  endif
  call s:update()
endfunction " }}}

function! s:action_stage(statuses, options) abort " {{{
  let statuses = s:ensure_list(a:statuses)
  let options = extend({
        \ 'force': 0,
        \}, a:options)
  let add_statuses = []
  let rm_statuses = []
  for status in statuses
    if status.is_conflicted
      call gita#util#info(printf(join([
            \ 'A conflicted file "%s" cannot be staged.',
            \ 'Use <Plug>(gita-action-add) or <Plug>(gita-action-rm) instead.',
            \ ]), status.path)
            \)
      continue
    elseif status.is_unstaged && status.worktree ==# 'D'
      call add(rm_statuses, status)
    else
      if s:validate_status_add(status, options)
        continue
      endif
      call add(add_statuses, status)
    endif
  endfor
  if empty(add_statuses) && empty(rm_statuses)
    if !get(options, 'ignore_empty_warning', 0)
      call gita#util#warn(
            \ 'No valid files were selected for stage action',
            \)
    endif
    return
  endif
  let options.ignore_empty_warning = 1
  call s:action_add(add_statuses, options)
  call s:action_rm(rm_statuses, options)
  call s:update()
endfunction " }}}
function! s:action_unstage(statuses, options) abort " {{{
  call s:action_reset(a:statuses, a:options)
endfunction " }}}
function! s:action_toggle(statuses, options) abort " {{{
  let statuses = s:ensure_list(a:statuses)
  let options = extend({
        \ 'force': 0,
        \}, a:options)
  let stage_statuses = []
  let unstage_statuses = []
  for status in statuses
    if status.is_conflicted
      call gita#util#info(printf(join([
            \ 'A conflicted file "%s" cannot be toggle.',
            \ 'Use <Plug>(gita-action-add) or <Plug>(gita-action-rm) instead.',
            \ ]), status.path)
            \)
      continue
    elseif status.is_staged && status.is_unstaged
      if get(g:, 'gita#interface#status#action_prefer_unstage', 0)
        call add(stage_statuses, status)
      else
        call add(unstage_statuses, status)
      endif
    elseif status.is_staged
      call add(unstage_statuses, status)
    elseif status.is_untracked || status.is_unstaged || status.is_ignored
      call add(stage_statuses, status)
    endif
  endfor
  if empty(stage_statuses) && empty(unstage_statuses)
    if !get(options, 'ignore_empty_warning', 0)
      call gita#util#warn(
            \ 'No valid files were selected for toggle action',
            \)
    endif
    return
  endif
  let options.ignore_empty_warning = 1
  call s:action_stage(stage_statuses, options)
  call s:action_unstage(unstage_statuses, options)
  call s:update()
endfunction " }}}
function! s:action_discard(statuses, options) abort " {{{
  let statuses = s:ensure_list(a:statuses)
  let options = extend({
        \ 'confirm': 1,
        \}, a:options)
  let delete_statuses = []
  let checkout_statuses = []
  for status in statuses
    if status.is_untracked || status.is_ignored
      call add(delete_statuses, status)
    elseif status.is_staged || status.is_unstaged
      call add(checkout_statuses, status)
    else
      " conflicted
      call gita#util#info(
            \ printf('A discard action cannot be performed on a conflicted file "%s".', status.path)
            \)
      continue
    endif
  endfor
  if empty(delete_statuses) && empty(checkout_statuses)
    if !get(options, 'ignore_empty_warning', 0)
      call gita#util#warn(
            \ 'No valid files were selected for discard action',
            \)
    endif
    return
  endif
  if get(options, 'confirm', 1)
    call gita#util#warn(join([
          \ 'A discard action will discard all local changes on working tree',
          \ 'and the operation is irreversible, mean that you have no chance',
          \ 'to revert the operation.',
          \]))
    if !gita#util#asktf('Are you sure you want to discard the changes?')
      call gita#util#info(
            \ 'The operation has canceled by user.'
            \)
      return
    endif
  endif
  for status in delete_statuses
    call delete(get(status, 'path2', status.path))
  endfor
  let options.ignore_empty_warning = 1
  let options.commit = 'INDEX'
  let options.force = 1
  call s:action_checkout(checkout_statuses, options)
  call s:update()
endfunction " }}}

function! s:open(...) abort " {{{
  let gita    = s:get_gita()
  let invoker = gita#util#invoker_get()
  let options = extend({}, get(a:000, 0, {}))

  if !gita.enabled
    redraw | call gita#util#info(
          \ printf(
          \   'Git is not available in the current buffer "%s".',
          \   bufname('%')
          \))
    return
  endif

  call gita#util#interface_open(s:const.bufname)
  silent execute 'setlocal filetype=' . s:const.filetype

  let b:_gita = gita
  let b:_invoker = invoker
  let b:_options = options

  " check if construction is required
  if exists('b:_constructed') && !get(g:, 'gita#debug', 0)
    " construction is not required.
    call s:update()
    return
  endif
  let b:_constructed = 1

  " construction
  setlocal buftype=nofile bufhidden=hide noswapfile nobuflisted
  setlocal winfixheight
  setlocal cursorline

  autocmd! * <buffer>
  " Note:
  "
  " :wq       : QuitPre > BufWriteCmd > WinLeave > BufWinLeave
  " :q        : QuitPre > WinLeave > BufWinLeave
  " :e        : BufWinLeave
  " :wincmd w : WinLeave
  "
  " s:ac_quit need to be called after BufWriteCmd and only when closing a
  " buffre window (not when :e, :wincmd w).
  " That's why the following autocmd combination is required.
  autocmd WinEnter    <buffer> let b:_winleave = 0
  autocmd WinLeave    <buffer> let b:_winleave = 1
  autocmd BufWinEnter <buffer> let b:_winleave = 0
  autocmd BufWinLeave <buffer> if get(b:, '_winleave', 0) | call s:ac_quit() | endif

  " define mappings
  call s:defmap()

  " update contents
  call s:update()
endfunction " }}}
function! s:update(...) abort " {{{
  let gita = s:get_gita()
  let options = extend(b:_options, get(a:000, 0, {}))
  let result = gita.git.get_parsed_status(
        \ extend({ 'no_cache': 1 }, options),
        \)
  if get(result, 'status', 0)
    redraw | call gita#util#error(
          \ result.stdout,
          \ printf('Fail: %s', join(result.args)),
          \)
    return
  endif

  " create statuses lines & map
  let statuses_map = {}
  let statuses_lines = []
  for status in result.all
    call add(statuses_lines, status.record)
    let statuses_map[status.record] = status
  endfor
  let gita.interface.status.statuses_map = statuses_map

  " create buffer lines
  let buflines = s:List.flatten([
        \ ['# Press ?m and/or ?s to toggle a help of mapping and/or short format.'],
        \ s:get_help('status_mapping'),
        \ s:get_help('short_format'),
        \ gita#util#interface_get_misc_lines(),
        \ statuses_lines,
        \ empty(statuses_map) ? ['Nothing to commit (Working tree is clean).'] : [],
        \])

  " update content
  setlocal modifiable
  call gita#util#buffer_update(buflines)
  setlocal nomodifiable
endfunction " }}}
function! s:defmap() abort " {{{
  nnoremap <silent><buffer> <Plug>(gita-action-help-m)   :<C-u>call <SID>action('help', { 'about': 'status_mapping' })<CR>
  nnoremap <silent><buffer> <Plug>(gita-action-help-s)   :<C-u>call <SID>action('help', { 'about': 'short_format' })<CR>

  nnoremap <silent><buffer> <Plug>(gita-action-update)   :<C-u>call <SID>action('update')<CR>
  nnoremap <silent><buffer> <Plug>(gita-action-switch)   :<C-u>call <SID>action('open_commit')<CR>
  nnoremap <silent><buffer> <Plug>(gita-action-commit)   :<C-u>call <SID>action('open_commit', { 'new': 1, 'amend': 0 })<CR>
  nnoremap <silent><buffer> <Plug>(gita-action-commit-a) :<C-u>call <SID>action('open_commit', { 'new': 1, 'amend': 1 })<CR>
  nnoremap <silent><buffer> <Plug>(gita-action-open)     :<C-u>call <SID>action('open', { 'opener': 'edit' })<CR>
  nnoremap <silent><buffer> <Plug>(gita-action-open-h)   :<C-u>call <SID>action('open', { 'opener': 'botright split' })<CR>
  nnoremap <silent><buffer> <Plug>(gita-action-open-v)   :<C-u>call <SID>action('open', { 'opener': 'botright vsplit' })<CR>
  nnoremap <silent><buffer> <Plug>(gita-action-open-s)   :<C-u>call <SID>action('open', { 'opener': 'select' })<CR>
  nnoremap <silent><buffer> <Plug>(gita-action-diff)     :<C-u>call <SID>action('diff_open', { 'opener': 'edit' })<CR>
  nnoremap <silent><buffer> <Plug>(gita-action-diff-h)   :<C-u>call <SID>action('diff_compare', { 'opener': 'tabnew', 'vertical': 0 })<CR>
  nnoremap <silent><buffer> <Plug>(gita-action-diff-v)   :<C-u>call <SID>action('diff_compare', { 'opener': 'tabnew', 'vertical': 1 })<CR>
  nnoremap <silent><buffer> <Plug>(gita-action-conflict2-h) :<C-u>call <SID>action('conflict2', { 'opener': 'tabnew', 'vertical': 0 })<CR>
  nnoremap <silent><buffer> <Plug>(gita-action-conflict2-v) :<C-u>call <SID>action('conflict2', { 'opener': 'tabnew', 'vertical': 1 })<CR>
  nnoremap <silent><buffer> <Plug>(gita-action-conflict3-h) :<C-u>call <SID>action('conflict3', { 'opener': 'tabnew', 'vertical': 0 })<CR>
  nnoremap <silent><buffer> <Plug>(gita-action-conflict3-v) :<C-u>call <SID>action('conflict3', { 'opener': 'tabnew', 'vertical': 1 })<CR>

  nnoremap <silent><buffer> <Plug>(gita-action-add)      :<C-u>call <SID>action('add')<CR>
  nnoremap <silent><buffer> <Plug>(gita-action-ADD)      :<C-u>call <SID>action('add', { 'force': 1 })<CR>
  nnoremap <silent><buffer> <Plug>(gita-action-rm)       :<C-u>call <SID>action('rm')<CR>
  nnoremap <silent><buffer> <Plug>(gita-action-RM)       :<C-u>call <SID>action('RM', { 'force': 1 })<CR>
  nnoremap <silent><buffer> <Plug>(gita-action-reset)    :<C-u>call <SID>action('reset')<CR>
  nnoremap <silent><buffer> <Plug>(gita-action-checkout) :<C-u>call <SID>action('checkout')<CR>
  nnoremap <silent><buffer> <Plug>(gita-action-CHECKOUT) :<C-u>call <SID>action('checkout', { 'force': 1 })<CR>
  nnoremap <silent><buffer> <Plug>(gita-action-ours)     :<C-u>call <SID>action('ours')<CR>
  nnoremap <silent><buffer> <Plug>(gita-action-theirs)   :<C-u>call <SID>action('theirs')<CR>
  nnoremap <silent><buffer> <Plug>(gita-action-stage)    :<C-u>call <SID>action('stage')<CR>
  nnoremap <silent><buffer> <Plug>(gita-action-unstage)  :<C-u>call <SID>action('unstage')<CR>
  nnoremap <silent><buffer> <Plug>(gita-action-toggle)   :<C-u>call <SID>action('toggle')<CR>
  nnoremap <silent><buffer> <Plug>(gita-action-discard)  :<C-u>call <SID>action('discard')<CR>

  vnoremap <silent><buffer> <Plug>(gita-action-add)      :<C-u>call <SID>action('add', 1)<CR>
  vnoremap <silent><buffer> <Plug>(gita-action-ADD)      :<C-u>call <SID>action('add', 1, { 'force': 1 })<CR>
  vnoremap <silent><buffer> <Plug>(gita-action-rm)       :<C-u>call <SID>action('rm', 1)<CR>
  vnoremap <silent><buffer> <Plug>(gita-action-RM)       :<C-u>call <SID>action('RM', 1, { 'force': 1 })<CR>
  vnoremap <silent><buffer> <Plug>(gita-action-reset)    :<C-u>call <SID>action('reset', 1)<CR>
  vnoremap <silent><buffer> <Plug>(gita-action-checkout) :<C-u>call <SID>action('checkout', 1)<CR>
  vnoremap <silent><buffer> <Plug>(gita-action-CHECKOUT) :<C-u>call <SID>action('checkout', 1, { 'force': 1 })<CR>
  vnoremap <silent><buffer> <Plug>(gita-action-ours)     :<C-u>call <SID>action('ours', 1)<CR>
  vnoremap <silent><buffer> <Plug>(gita-action-theirs)   :<C-u>call <SID>action('theirs', 1)<CR>
  vnoremap <silent><buffer> <Plug>(gita-action-stage)    :<C-u>call <SID>action('stage', 1)<CR>
  vnoremap <silent><buffer> <Plug>(gita-action-unstage)  :<C-u>call <SID>action('unstage', 1)<CR>
  vnoremap <silent><buffer> <Plug>(gita-action-toggle)   :<C-u>call <SID>action('toggle', 1)<CR>
  vnoremap <silent><buffer> <Plug>(gita-action-discard)  :<C-u>call <SID>action('discard', 1)<CR>

  " aliases (long name)
  nmap <buffer> <Plug>(gita-action-unstage)         <Plug>(gita-action-reset)
  nmap <buffer> <Plug>(gita-action-help-mappings)   <Plug>(gita-action-help-m)
  nmap <buffer> <Plug>(gita-action-help-symbols)    <Plug>(gita-action-help-s)
  nmap <buffer> <Plug>(gita-action-commit-amend)    <Plug>(gita-action-commit-a)
  nmap <buffer> <Plug>(gita-action-open-horizontal) <Plug>(gita-action-open-h)
  nmap <buffer> <Plug>(gita-action-open-vertical)   <Plug>(gita-action-open-v)
  nmap <buffer> <Plug>(gita-action-open-select)     <Plug>(gita-action-open-s)
  nmap <buffer> <Plug>(gita-action-diff-horizontal) <Plug>(gita-action-diff-h)
  nmap <buffer> <Plug>(gita-action-diff-vertical)   <Plug>(gita-action-diff-v)

  if get(g:, 'gita#interface#status#enable_default_keymap', 1)
    nmap <buffer><silent> q  :<C-u>quit<CR>
    nmap <buffer> <C-l> <Plug>(gita-action-update)

    nmap <buffer> ?m <Plug>(gita-action-help-m)
    nmap <buffer> ?s <Plug>(gita-action-help-s)

    nmap <buffer> cc <Plug>(gita-action-switch)
    nmap <buffer> cC <Plug>(gita-action-commit)
    nmap <buffer> cA <Plug>(gita-action-commit-a)

    nmap <buffer><expr> e  <SID>smart_map('e', '<Plug>(gita-action-open)')
    nmap <buffer><expr> E  <SID>smart_map('E', '<Plug>(gita-action-open-v)')
    nmap <buffer><expr> s  <SID>smart_map('s', '<Plug>(gita-action-open-s)')
    nmap <buffer><expr> d  <SID>smart_map('d', '<Plug>(gita-action-diff)')
    nmap <buffer><expr> D  <SID>smart_map('D', '<Plug>(gita-action-diff-v)')
    nmap <buffer><expr> s  <SID>smart_map('s', '<Plug>(gita-action-conflict2-v)')
    nmap <buffer><expr> S  <SID>smart_map('S', '<Plug>(gita-action-conflict3-v)')

    " operation
    nmap <buffer><expr> << <SID>smart_map('<<', '<Plug>(gita-action-stage)')
    nmap <buffer><expr> >> <SID>smart_map('>>', '<Plug>(gita-action-unstage)')
    nmap <buffer><expr> -- <SID>smart_map('--', '<Plug>(gita-action-toggle)')
    nmap <buffer><expr> == <SID>smart_map('==', '<Plug>(gita-action-discard)')

    " raw operation
    nmap <buffer><expr> -a <SID>smart_map('-a', '<Plug>(gita-action-add)')
    nmap <buffer><expr> -A <SID>smart_map('-A', '<Plug>(gita-action-ADD)')
    nmap <buffer><expr> -r <SID>smart_map('-r', '<Plug>(gita-action-reset)')
    nmap <buffer><expr> -d <SID>smart_map('-d', '<Plug>(gita-action-rm)')
    nmap <buffer><expr> -D <SID>smart_map('-D', '<Plug>(gita-action-RM)')
    nmap <buffer><expr> -c <SID>smart_map('-c', '<Plug>(gita-action-checkout)')
    nmap <buffer><expr> -C <SID>smart_map('-C', '<Plug>(gita-action-CHECKOUT)')
    nmap <buffer><expr> -o <SID>smart_map('-o', '<Plug>(gita-action-ours)')
    nmap <buffer><expr> -t <SID>smart_map('-t', '<Plug>(gita-action-theirs)')

    vmap <buffer> << <Plug>(gita-action-stage)
    vmap <buffer> >> <Plug>(gita-action-unstage)
    vmap <buffer> -- <Plug>(gita-action-toggle)
    vmap <buffer> == <Plug>(gita-action-discard)

    vmap <buffer> -a <Plug>(gita-action-add)
    vmap <buffer> -A <Plug>(gita-action-ADD)
    vmap <buffer> -r <Plug>(gita-action-reset)
    vmap <buffer> -d <Plug>(gita-action-rm)
    vmap <buffer> -D <Plug>(gita-action-RM)
    vmap <buffer> -c <Plug>(gita-action-checkout)
    vmap <buffer> -C <Plug>(gita-action-CHECKOUT)
    vmap <buffer> -o <Plug>(gita-action-ours)
    vmap <buffer> -t <Plug>(gita-action-theirs)
  endif
endfunction " }}}
function! s:ac_quit() abort " {{{
  call gita#util#invoker_focus()
endfunction " }}}

" Private API
function! gita#interface#status#define_highlights() abort " {{{
  highlight link GitaComment    Comment
  highlight link GitaConflicted Error
  highlight link GitaUnstaged   Constant
  highlight link GitaStaged     Special
  highlight link GitaUntracked  GitaUnstaged
  highlight link GitaIgnored    Identifier
  highlight link GitaBranch     Title
endfunction " }}}
function! gita#interface#status#define_syntax() abort " {{{
  syntax match GitaStaged     /\v^[ MADRC][ MD]/he=e-1 contains=ALL
  syntax match GitaUnstaged   /\v^[ MADRC][ MD]/hs=s+1 contains=ALL
  syntax match GitaStaged     /\v^[ MADRC]\s.*$/hs=s+3 contains=ALL
  syntax match GitaUnstaged   /\v^.[MDAU?].*$/hs=s+3 contains=ALL
  syntax match GitaIgnored    /\v^\!\!\s.*$/
  syntax match GitaUntracked  /\v^\?\?\s.*$/
  syntax match GitaConflicted /\v^%(DD|AU|UD|UA|DU|AA|UU)\s.*$/
  syntax match GitaComment    /\v^.*$/ contains=ALL
  syntax match GitaBranch     /\v`[^`]{-}`/hs=s+1,he=e-1
endfunction " }}}

" Public API
function! gita#interface#status#open(...) abort " {{{
  call call('s:open', a:000)
endfunction " }}}
function! gita#interface#status#update(...) abort " {{{
  if bufname('%') !=# s:const.bufname
    call call('s:open', a:000)
  else
    call call('s:update', a:000)
  endif
endfunction " }}}
function! gita#interface#status#action(name, ...) abort " {{{
  if s:validate_filetype('gita#interface#status#action()')
    return
  endif
  call call('s:action', extend([a:name], a:000))
endfunction " }}}
function! gita#interface#status#smart_map(lhs, rhs) abort " {{{
  if s:validate_filetype('gita#interface#status#smart_map()')
    return
  endif
  call call('s:smart_map', [a:lhs, a:rhs])
endfunction " }}}
function! gita#interface#status#get_selected_status() abort " {{{
  if s:validate_filetype('gita#interface#status#get_selected_status()')
    return
  endif
  return call('s:get_selected_status', a:000)
endfunction " }}}
function! gita#interface#status#get_selected_statuses() abort " {{{
  if s:validate_filetype('gita#interface#status#get_selected_statuses()')
    return
  endif
  return call('s:get_selected_statuses', a:000)
endfunction " }}}

let &cpo = s:save_cpo
unlet! s:save_cpo
"vim: stts=2 sw=2 smarttab et ai textwidth=0 fdm=marker

