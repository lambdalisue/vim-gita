let s:save_cpo = &cpo
set cpo&vim

let s:const = {}
let s:const.bufname = has('unix') ? 'gita:status' : 'gita_status'
let s:const.filetype = 'gita-status'


" Modules
let s:P = gita#utils#import('Prelude')
let s:L = gita#utils#import('Data.List')
let s:D = gita#utils#import('Data.Dict')
let s:F = gita#utils#import('System.File')
let s:A = gita#utils#import('ArgumentParser')


" Private
function! s:get_parser() abort " {{{
  if !exists('s:parser') || get(g:, 'gita#debug', 0)
    let s:parser = s:A.new({
          \ 'name': 'Show the working tree status in Gita interface',
          \})
    call s:parser.add_argument(
          \ '--untracked-files', '-u',
          \ 'show untracked files, optional modes: all, normal, no. (Default: all)', {
          \   'choices': ['all', 'normal', 'no'],
          \   'on_default': 'all',
          \ })
    call s:parser.add_argument(
          \ '--ignored',
          \ 'show ignored files', {
          \ })
    call s:parser.add_argument(
          \ '--ignore-submodules',
          \ 'ignore changes to submodules, optional when: all, dirty, untracked (Default: all)', {
          \   'choices': ['all', 'dirty', 'untracked'],
          \   'on_default': 'all',
          \ })
  endif
  return s:parser
endfunction " }}}

function! s:get_gita(...) abort " {{{
  return call('gita#core#get', a:000)
endfunction " }}}
function! s:get_invoker(...) abort " {{{
  return call('gita#utils#invoker#get', a:000)
endfunction " }}}
function! s:get_statuses_map() abort " {{{
  return get(w:, '_gita_statuses_map', {})
endfunction " }}}
function! s:set_statuses_map(statuses_map) abort " {{{
  let w:_gita_statuses_map = deepcopy(a:statuses_map)
endfunction " }}}
function! s:get_statuses_within(start, end) abort " {{{
  " Use with 'range' a:startline, a:lastline
  let statuses_map = s:get_statuses_map()
  let statuses = []
  for n in range(a:start, a:end)
    let status = get(statuses_map, getline(n), {})
    if !empty(status)
      call add(statuses, status)
    endif
  endfor
  return statuses
endfunction " }}}
function! s:get_status_header(gita) abort " {{{
  let meta = a:gita.git.get_meta()
  let name = fnamemodify(a:gita.git.worktree, ':t')
  let branch = meta.current_branch
  let remote_name = meta.current_branch_remote
  let remote_branch = meta.current_remote_branch
  let outgoing = a:gita.git.count_commits_ahead_of_remote()
  let incoming = a:gita.git.count_commits_behind_remote()
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
function! s:get_status_abspath(gita, status) abort " {{{
  let path = get(a:status, 'path2', a:status.path)
  return a:gita.git.get_absolute_path(path)
endfunction " }}}
function! s:smart_map(lhs, rhs) abort " {{{
  " check if the cursor is on a status line or not
  return empty(s:get_statuses_within(a:firstline, a:firstline)) ? a:lhs : a:rhs
endfunction " }}}

function! s:open(...) abort " {{{
  let options = extend(
        \ get(w:, '_gita_options', {}),
        \ get(a:000, 0, {}),
        \)
  let gita    = s:get_gita()
  let invoker = s:get_invoker()

  if !gita.enabled
    redraw
    call gita#utils#warn(
          \ 'Gita is not available in the current buffer.',
          \)
    call gita#utils#debugmsg(
          \ 'gita#features#status#s:open',
          \ printf('bufname: "%s"', bufname('%')),
          \ printf('cwd: "%s"', getcwd()),
          \ printf('gita: "%s"', string(gita)),
          \)
    return
  endif

  call gita#utils#buffer#open(s:const.bufname, 'support_window', {
        \ 'opener': 'topleft 15 split',
        \ 'range': 'tabpage',
        \})
  silent execute printf('setlocal filetype=%s', s:const.filetype)

  if get(options, 'new', 0)
    let options = get(a:000, 0, {})
  endif

  " update buffer variables
  let w:_gita = gita
  let w:_gita_options = s:D.omit(options, [
        \ 'new',
        \])
  call invoker.update_winnum()
  call gita#utils#invoker#set(invoker)

  " check if construction is required
  if get(b:, '_gita_constructed') && !get(g:, 'gita#debug', 0)
    call s:update(options)
    return
  endif
  let b:_gita_constructed = 1

  " construction
  setlocal buftype=nofile bufhidden=hide noswapfile nobuflisted
  setlocal winfixwidth winfixheight
  setlocal cursorline
  setlocal nomodifiable

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

  call s:defmap()
  call s:update(options)
endfunction " }}}
function! s:update(...) abort " {{{
  let options = extend(
        \ get(w:, '_gita_options', {}),
        \ get(a:000, 0, {}),
        \)
  let gita = s:get_gita()

  let result = gita.git.get_parsed_status(extend({
        \ 'no_cache': 1,
        \}, options))
  if get(result, 'status', 0)
    redraw
    call gita#utils#errormsg(
          \ printf('vim-gita: Fail: %s', join(result.args)),
          \)
    call gita#utils#infomsg(
          \ result.stdout,
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
  call s:set_statuses_map(statuses_map)

  " create buffer lines
  let buflines = s:L.flatten([
        \ ['# Press ?m and/or ?s to toggle a help of mapping and/or short format.'],
        \ gita#utils#help#get('status_mapping'),
        \ gita#utils#help#get('short_format'),
        \ s:get_status_header(gita),
        \ statuses_lines,
        \ empty(statuses_map) ? ['Nothing to commit (Working tree is clean).'] : [],
        \])

  " update content
  call gita#utils#buffer#update(buflines)
endfunction " }}}
function! s:defmap() abort " {{{
  noremap <silent><buffer> <Plug>(gita-action-help-m)   :call <SID>action('help', { 'name': 'status_mapping' })<CR>
  noremap <silent><buffer> <Plug>(gita-action-help-s)   :call <SID>action('help', { 'name': 'short_format' })<CR>

  noremap <silent><buffer> <Plug>(gita-action-update)   :call <SID>action('update')<CR>
  noremap <silent><buffer> <Plug>(gita-action-switch)   :call <SID>action('open_commit')<CR>
  noremap <silent><buffer> <Plug>(gita-action-commit)   :call <SID>action('open_commit', { 'new': 1, 'amend': 0 })<CR>
  noremap <silent><buffer> <Plug>(gita-action-commit-a) :call <SID>action('open_commit', { 'new': 1, 'amend': 1 })<CR>
  noremap <silent><buffer> <Plug>(gita-action-open)     :call <SID>action('open')<CR>
  noremap <silent><buffer> <Plug>(gita-action-open-h)   :call <SID>action('open', { 'opener': 'botright split' })<CR>
  noremap <silent><buffer> <Plug>(gita-action-open-v)   :call <SID>action('open', { 'opener': 'botright vsplit' })<CR>
  noremap <silent><buffer> <Plug>(gita-action-diff)     :call <SID>action('diff_open')<CR>
  noremap <silent><buffer> <Plug>(gita-action-diff-h)   :call <SID>action('diff_diff', { 'vertical': 0 })<CR>
  noremap <silent><buffer> <Plug>(gita-action-diff-v)   :call <SID>action('diff_diff', { 'vertical': 1 })<CR>
  noremap <silent><buffer> <Plug>(gita-action-solve2-h) :call <SID>action('solve2', { 'vertical': 0 })<CR>
  noremap <silent><buffer> <Plug>(gita-action-solve2-v) :call <SID>action('solve2', { 'vertical': 1 })<CR>
  noremap <silent><buffer> <Plug>(gita-action-solve3-h) :call <SID>action('solve3', { 'vertical': 0 })<CR>
  noremap <silent><buffer> <Plug>(gita-action-solve3-v) :call <SID>action('solve3', { 'vertical': 1 })<CR>

  noremap <silent><buffer> <Plug>(gita-action-add)      :call <SID>action('add')<CR>
  noremap <silent><buffer> <Plug>(gita-action-ADD)      :call <SID>action('add', { 'force': 1 })<CR>
  noremap <silent><buffer> <Plug>(gita-action-rm)       :call <SID>action('rm')<CR>
  noremap <silent><buffer> <Plug>(gita-action-RM)       :call <SID>action('RM', { 'force': 1 })<CR>
  noremap <silent><buffer> <Plug>(gita-action-reset)    :call <SID>action('reset')<CR>
  noremap <silent><buffer> <Plug>(gita-action-checkout) :call <SID>action('checkout')<CR>
  noremap <silent><buffer> <Plug>(gita-action-CHECKOUT) :call <SID>action('checkout', { 'force': 1 })<CR>
  noremap <silent><buffer> <Plug>(gita-action-ours)     :call <SID>action('ours')<CR>
  noremap <silent><buffer> <Plug>(gita-action-theirs)   :call <SID>action('theirs')<CR>
  noremap <silent><buffer> <Plug>(gita-action-stage)    :call <SID>action('stage')<CR>
  noremap <silent><buffer> <Plug>(gita-action-unstage)  :call <SID>action('unstage')<CR>
  noremap <silent><buffer> <Plug>(gita-action-toggle)   :call <SID>action('toggle')<CR>
  noremap <silent><buffer> <Plug>(gita-action-discard)  :call <SID>action('discard')<CR>

  if get(g:, 'gita#features#status#enable_default_keymap', 1)
    nmap <buffer><silent> q  :<C-u>quit<CR>
    nmap <buffer> <C-l> <Plug>(gita-action-update)

    nmap <buffer> ?m <Plug>(gita-action-help-m)
    nmap <buffer> ?s <Plug>(gita-action-help-s)

    nmap <buffer> cc <Plug>(gita-action-switch)
    nmap <buffer> cC <Plug>(gita-action-commit)
    nmap <buffer> cA <Plug>(gita-action-commit-a)

    nmap <buffer><expr> e  <SID>smart_map('e', '<Plug>(gita-action-open)')
    nmap <buffer><expr> E  <SID>smart_map('E', '<Plug>(gita-action-open-v)')
    nmap <buffer><expr> d  <SID>smart_map('d', '<Plug>(gita-action-diff)')
    nmap <buffer><expr> D  <SID>smart_map('D', '<Plug>(gita-action-diff-v)')
    nmap <buffer><expr> s  <SID>smart_map('s', '<Plug>(gita-action-solve2-v)')
    nmap <buffer><expr> S  <SID>smart_map('S', '<Plug>(gita-action-solve3-v)')

    " operations
    nmap <buffer><expr> << <SID>smart_map('<<', '<Plug>(gita-action-stage)')
    nmap <buffer><expr> >> <SID>smart_map('>>', '<Plug>(gita-action-unstage)')
    nmap <buffer><expr> -- <SID>smart_map('--', '<Plug>(gita-action-toggle)')
    nmap <buffer><expr> == <SID>smart_map('==', '<Plug>(gita-action-discard)')

    " raw operations
    nmap <buffer><expr> -a <SID>smart_map('-a', '<Plug>(gita-action-add)')
    nmap <buffer><expr> -A <SID>smart_map('-A', '<Plug>(gita-action-ADD)')
    nmap <buffer><expr> -r <SID>smart_map('-r', '<Plug>(gita-action-reset)')
    nmap <buffer><expr> -d <SID>smart_map('-d', '<Plug>(gita-action-rm)')
    nmap <buffer><expr> -D <SID>smart_map('-D', '<Plug>(gita-action-RM)')
    nmap <buffer><expr> -c <SID>smart_map('-c', '<Plug>(gita-action-checkout)')
    nmap <buffer><expr> -C <SID>smart_map('-C', '<Plug>(gita-action-CHECKOUT)')
    nmap <buffer><expr> -o <SID>smart_map('-o', '<Plug>(gita-action-ours)')
    nmap <buffer><expr> -t <SID>smart_map('-t', '<Plug>(gita-action-theirs)')

    " operations (range)
    vmap <buffer> << <Plug>(gita-action-stage)
    vmap <buffer> >> <Plug>(gita-action-unstage)
    vmap <buffer> -- <Plug>(gita-action-toggle)
    vmap <buffer> == <Plug>(gita-action-discard)

    " raw operations (range)
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
  call gita#utils#invoker#focus()
  call gita#utils#invoker#clear()
endfunction " }}}

function! s:action(name, ...) range abort " {{{
  let update_required_action_pattern = printf('^\%%(%s\)', join([
        \ 'help',
        \ 'add', 'rm', 'reset',
        \ 'checkout', 'checkout_ours', 'checkout_theirs',
        \ 'stage', 'unstage', 'toggle', 'discard',
        \], '\|'))
  "let options  = extend(deepcopy(w:_gita_options), get(a:000, 0, {}))
  let options  = get(a:000, 0, {})
  let statuses = s:get_statuses_within(a:firstline, a:lastline)
  let args = [statuses, options]
  call call(printf('s:action_%s', a:name), args)
  if a:name =~# update_required_action_pattern
    call s:update()
  endif
endfunction " }}}
function! s:action_update(statuses, options) abort " {{{
  call s:update(a:options)
endfunction " }}}
function! s:action_open_commit(statuses, options) abort " {{{
  call gita#features#commit#open(a:options)
endfunction " }}}
function! s:action_open(statuses, options) abort " {{{
  let gita = s:get_gita()
  let invoker = s:get_invoker()
  let opener = get(a:options, 'opener', 'edit')
  for status in a:statuses
    let abspath = s:get_status_abspath(gita, status)
    call invoker.focus()
    call gita#utils#buffer#open(abspath, '', {
          \ 'opener': opener,
          \})
  endfor
endfunction " }}}
function! s:action_diff_open(statuses, options) abort " {{{
:qa

:qa
  let commit = get(a:options, 'commit', '')
  if empty(commit)
    let commit = gita#utils#ask('Compare the file with: ', 'INDEX')
    if empty(commit)
      call gita#utils#warn(
            \ 'The operation has canceled by user.',
            \)
      return
    endif
  endif
  let commit = commit ==# 'INDEX' ? '' : commit
  let gita = s:get_gita()
  let invoker = s:get_invoker()
  for status in a:statuses
    let path = get(status, 'path2', get(status, 'path'))
    call invoker.focus()
    call gita#features#diff#open(path, commit, a:options)
  endfor
endfunction " }}}
function! s:action_diff_diff(statuses, options) abort " {{{
  let commit = get(a:options, 'commit', '')
  if empty(commit)
    let commit = gita#utils#ask('Compare the file with: ', 'INDEX')
    if empty(commit)
      call gita#utils#warn(
            \ 'The operation has canceled by user.',
            \)
      return
    endif
  endif
  let commit = commit ==# 'INDEX' ? '' : commit
  let gita = s:get_gita()
  let invoker = s:get_invoker()
  for status in a:statuses
    let path = get(status, 'path2', get(status, 'path'))
    call invoker.focus()
    call gita#features#diff#diff2(path, commit, a:options)
  endfor
endfunction " }}}
function! s:action_help(statuses, options) abort " {{{
  let name = a:options.name
  call gita#utils#help#toggle(name)
endfunction " }}}

function! s:action_add(statuses, options) abort " {{{
  call gita#features#add#action(a:statuses, a:options)
endfunction " }}}
function! s:action_rm(statuses, options) abort " {{{
  call gita#features#rm#action(a:statuses, a:options)
endfunction " }}}
function! s:action_reset(statuses, options) abort " {{{
  call gita#features#reset#action(a:statuses, a:options)
endfunction " }}}
function! s:action_checkout(statuses, options) abort " {{{
  call gita#features#checkout#action(a:statuses, a:options)
endfunction " }}}
function! s:action_checkout_ours(statuses, options) abort " {{{
  let options = deepcopy(a:options)
  let options.ours = 1
  call gita#features#checkout#action(a:statuses, options)
endfunction " }}}
function! s:action_checkout_theirs(statuses, options) abort " {{{
  let options = deepcopy(a:options)
  let options.theirs = 1
  call gita#features#checkout#action(a:statuses, options)
endfunction " }}}
function! s:action_stage(statuses, options) abort " {{{
  let statuses = gita#utils#ensure_list(a:statuses)
  let options = deepcopy(a:options)
  let add_statuses = []
  let rm_statuses = []
  for status in statuses
    if status.is_conflicted
      call gita#utils#warn(printf(
            \ 'A conflicted file "%s" cannot be staged. Use <Plug>(gita-action-add) or <Plug>(gita-action-rm) directly.',
            \ status.path,
            \))
      continue
    elseif status.is_unstaged && status.worktree ==# 'D'
      call add(rm_statuses, status)
    else
      call add(add_statuses, status)
    endif
  endfor
  if empty(add_statuses) && empty(rm_statuses)
    if !get(options, 'ignore_empty_warning', 0)
      call gita#utils#warn(
            \ 'No valid statuses were specified.',
            \)
    endif
    return
  endif
  let options.ignore_empty_warning = 1
  call s:action_add(add_statuses, options)
  call s:action_rm(rm_statuses, options)
endfunction " }}}
function! s:action_unstage(statuses, options) abort " {{{
  " this is a just alias of 's:action_reset'
  call s:action_reset(a:statuses, a:options)
endfunction " }}}
function! s:action_toggle(statuses, options) abort " {{{
  let statuses = gita#utils#ensure_list(a:statuses)
  let options = deepcopy(a:options)
  let stage_statuses = []
  let reset_statuses = []
  for status in statuses
    if status.is_conflicted
      call gita#utils#warn(printf(
            \ 'A conflicted file "%s" cannot be staged/unstaged. Use <Plug>(gita-action-add) or <Plug>(gita-action-rm) directly.',
            \ status.path,
            \))
      continue
    elseif status.is_staged && status.is_unstaged
      if get(g:, 'gita#features#status#action_toggle#prefer_unstage', 0)
        call add(reset_statuses, status)
      else
        call add(stage_statuses, status)
      endif
    elseif status.is_staged
      call add(reset_statuses, status)
    elseif status.is_unstaged || status.is_untracked || status.is_ignored
      call add(stage_statuses, status)
    else
      " it should not be called
      call gita#utils#errormsg(printf(
            \ 'An unexpected pattern "%s" is called for "toggle".',
            \ status.sign,
            \))
      call gita#utils#open_gita_issue()
    endif
  endfor
  if empty(stage_statuses) && empty(reset_statuses)
    if !get(options, 'ignore_empty_warning', 0)
      call gita#utils#warn(
            \ 'No valid statuses were specified.',
            \)
    endif
    return
  endif
  let options.ignore_empty_warning = 1
  call s:action_stage(stage_statuses, options)
  call s:action_reset(reset_statuses, options)
endfunction " }}}
function! s:action_discard(statuses, options) abort " {{{
  let statuses = gita#utils#ensure_list(a:statuses)
  let options = deepcopy(a:options)
  let delete_statuses = []
  let checkout_statuses = []
  for status in statuses
    if status.is_conflicted
      call gita#utils#warn(printf(
            \ 'A conflicted file "%s" cannot be discarded. Resolve the conflict first.',
            \ status.path,
            \))
      continue
    elseif status.is_untracked || status.is_ignored
      call add(delete_statuses, status)
    elseif status.is_staged || status.is_unstaged
      call add(checkout_statuses, status)
    else
      " it should not be called
      call gita#utils#errormsg(printf(
            \ 'An unexpected pattern "%s" is called for "discard".',
            \ status.sign,
            \))
      call gita#utils#open_gita_issue()
    endif
  endfor
  if empty(delete_statuses) && empty(checkout_statuses)
    if !get(options, 'ignore_empty_warning', 0)
      call gita#utils#warn(
            \ 'No valid statuses were specified.',
            \)
    endif
    return
  endif
  if get(options, 'confirm', 1)
    call gita#utils#warn(join([
          \ 'A discard action will discard all local changes on the working tree',
          \ 'and the operation is irreversible, mean that you have no chance to',
          \ 'revert the operation.',
          \]))
    if !gita#utils#asktf('Are you sure you want to discard the changes?')
      call gita#utils#info(
            \ 'The operation has canceled by user.'
            \)
      return
    endif
  endif
  " delete untracked files
  let gita = s:get_gita()
  for status in delete_statuses
    let path = s:get_status_abspath(gita, status)
    if isdirectory(path)
      silent! call s:F.rmdir(path, 'r')
    elseif filewritable(path)
      silent! call delete(path)
    endif
  endfor
  " checkout tracked files from HEAD
  let options.ignore_empty_warning = 1
  let options.commit = ''
  let options.force = 1
  call s:action_checkout(checkout_statuses, options)
endfunction " }}}


" Internal API
function! gita#features#status#get_statuses_map(...) abort " {{{
  return call('s:get_statuses_map', a:000)
endfunction " }}}
function! gita#features#status#set_statuses_map(...) abort " {{{
  return call('s:set_statuses_map', a:000)
endfunction " }}}
function! gita#features#status#get_statuses_within(...) abort " {{{
  return call('s:get_statuses_within', a:000)
endfunction " }}}
function! gita#features#status#get_status_header(...) abort " {{{
  return call('s:get_status_header', a:000)
endfunction " }}}
function! gita#features#status#get_status_abspath(...) abort " {{{
  return call('s:get_status_abspath', a:000)
endfunction " }}}
function! gita#features#status#smart_map(...) abort " {{{
  return call('s:smart_map', a:000)
endfunction " }}}
function! gita#features#status#action_open(...) abort " {{{
  call call('s:action_open', a:000)
endfunction " }}}
function! gita#features#status#action_diff_open(...) abort " {{{
  call call('s:action_diff_open', a:000)
endfunction " }}}
function! gita#features#status#action_diff_diff(...) abort " {{{
  call call('s:action_diff_diff', a:000)
endfunction " }}}
function! gita#features#status#action_help(...) abort " {{{
  call call('s:action_help', a:000)
endfunction " }}}
function! gita#features#status#open(...) abort " {{{
  call call('s:open', a:000)
endfunction " }}}
function! gita#features#status#update(...) abort " {{{
  call call('s:update', a:000)
endfunction " }}}
function! gita#features#status#define_highlights() abort " {{{
  highlight link GitaComment    Comment
  highlight link GitaConflicted Error
  highlight link GitaUnstaged   Constant
  highlight link GitaStaged     Special
  highlight link GitaUntracked  GitaUnstaged
  highlight link GitaIgnored    Identifier
  highlight link GitaBranch     Title
endfunction " }}}
function! gita#features#status#define_syntax() abort " {{{
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


" External API
function! gita#features#status#command(bang, range, ...) abort " {{{
  let parser = s:get_parser()
  let opts = parser.parse(a:bang, a:range, get(a:000, 0, ''))
  if !empty(opts)
    call s:open(opts)
  endif
endfunction " }}}
function! gita#features#status#complete(arglead, cmdline, cursorpos) abort " {{{
  let parser = s:get_parser()
  let candidates = parser.complete(a:arglead, a:cmdline, a:cursorpos)
  return candidates
endfunction " }}}


let &cpo = s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
