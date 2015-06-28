let s:save_cpo = &cpo
set cpo&vim


let s:L = gita#utils#import('Data.List')
let s:D = gita#utils#import('Data.Dict')
let s:F = gita#utils#import('System.File')
let s:S = gita#utils#import('VCS.Git.StatusParser')
let s:A = gita#utils#import('ArgumentParser')

let s:const = {}
let s:const.bufname_sep = has('unix') ? ':' : '-'
let s:const.bufname = join(['gita', 'status'], s:const.bufname_sep)
let s:const.filetype = 'gita-status'

let s:parser = s:A.new({
      \ 'name': 'Gita status',
      \ 'description': 'Show the working tree status',
      \})
call s:parser.add_argument(
      \ '--window', '-w',
      \ 'Open a gita:status window to manipulate the working tree status (Default behavior)', {
      \   'deniable': 1,
      \   'default': 1,
      \ })
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
" TODO: Add more arguments

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
function! s:smart_map(...) abort " {{{
  return call('gita#display#smart_map', a:000)
endfunction " }}}

let s:actions = {}
function! s:actions.update(statuses, options) abort " {{{
  call gita#features#status#update(a:options)
endfunction " }}}
function! s:actions.open_commit(statuses, options) abort " {{{
  call gita#features#commit#open(a:options)
endfunction " }}}
function! s:actions.add(statuses, options) abort " {{{
  if empty(a:statuses)
    return
  endif
  let options = extend({
        \ '--': map(deepcopy(a:statuses), 'v:val.path'),
        \ 'ignore_errors': 1,
        \}, a:options)
  call gita#features#add#exec(options, {
        \ 'echo': 'fail',
        \})
  call self.update(a:statuses, a:options)
endfunction " }}}
function! s:actions.rm(statuses, options) abort " {{{
  if empty(a:statuses)
    return
  endif
  let options = extend({
        \ '--': map(deepcopy(a:statuses), 'v:val.path'),
        \ 'quiet': 1,
        \}, a:options)
  call gita#features#rm#exec(options, {
        \ 'echo': 'fail',
        \})
  call self.update(a:statuses, a:options)
endfunction " }}}
function! s:actions.reset(statuses, options) abort " {{{
  if empty(a:statuses)
    return
  endif
  let options = extend({
        \ '--': map(deepcopy(a:statuses), 'v:val.path'),
        \ 'quiet': 1,
        \}, a:options)
  call gita#features#reset#exec(options, {
        \ 'echo': 'fail',
        \})
  call self.update(a:statuses, a:options)
endfunction " }}}
function! s:actions.checkout(statuses, options) abort " {{{
  if empty(a:statuses)
    return
  endif
  let options = extend({
        \ '--': map(deepcopy(a:statuses), 'v:val.path'),
        \}, a:options)
  call gita#features#checkout#exec(options, {
        \ 'echo': 'fail',
        \})
  call self.update(a:statuses, a:options)
endfunction " }}}
function! s:actions.stage(statuses, options) abort " {{{
  let add_statuses = []
  let rm_statuses = []
  for status in a:statuses
    if status.is_unstaged && status.worktree ==# 'D'
      call add(rm_statuses, status)
    else
      call add(add_statuses, status)
    endif
  endfor
  call self.add(add_statuses, a:options)
  call self.rm(rm_statuses, a:options)
endfunction " }}}
function! s:actions.unstage(statuses, options) abort " {{{
  call self.reset(a:statuses, a:options)
endfunction " }}}
function! s:actions.toggle(statuses, options) abort " {{{
  let stage_statuses = []
  let reset_statuses = []
  for status in a:statuses
    if status.is_staged && status.is_unstaged
      if get(g:, 'gita#features#status#prefer_unstage_in_toggle', 0)
        call add(reset_statuses, status)
      else
        call add(stage_statuses, status)
      endif
    elseif status.is_staged
      call add(reset_statuses, status)
    elseif status.is_unstaged || status.is_untracked || status.is_ignored
      call add(stage_statuses, status)
    endif
  endfor
  call self.stage(stage_statuses, a:options)
  call self.unstage(reset_statuses, a:options)
endfunction " }}}
function! s:actions.discard(statuses, options) abort " {{{
  let delete_statuses = []
  let checkout_statuses = []
  for status in a:statuses
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
    endif
  endfor
  if get(a:options, 'confirm', 1)
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
  let gita = gita#core#get()
  for status in delete_statuses
    let path = get(status, 'path2', status.path)
    let abspath = gita.git.get_absolute_path(path)
    if isdirectory(abspath)
      silent! call s:F.rmdir(abspath, 'r')
    elseif filewritable(abspath)
      silent! call delete(abspath)
    endif
  endfor
  " checkout tracked files from HEAD
  let options.commit = 'HEAD'
  let options.force = 1
  call self.checkout(checkout_statuses, a:options)
endfunction " }}}


function! gita#features#status#exec(...) abort " {{{
  let gita = gita#core#get()
  let options = get(a:000, 0, {})
  let config = get(a:000, 1, {})
  if gita.fail_on_disabled()
    return { 'status': -1 }
  endif
  if !empty(get(options, '--', []))
    call map(options['--'], 'gita#utils#expand(v:val)')
  endif
  let options = s:D.pick(options, [
        \ '--',
        \ 'porcelain',
        \ 'u', 'untracked_files',
        \ 'ignored',
        \ 'ignore_submodules',
        \])
  return gita.operations.status(options, config)
endfunction " }}}
function! gita#features#status#open(...) abort " {{{
  let result = gita#display#open(s:const.bufname, get(a:000, 0, {}))
  if result == -1
    " gita is not available
    return
  elseif result == 1
    " the buffer is already constructed
    call gita#features#status#update()
    silent execute printf("setlocal filetype=%s", s:const.filetype)
    return
  endif
  call gita#display#extend_actions(s:actions)

  " Define loccal options
  setlocal nomodifiable

  " Define extra Plug key mappings
  noremap <silent><buffer> <Plug>(gita-action-help-s)
        \ :<C-u>call gita#display#action('help', { 'name': 'short_format' })<CR>
  noremap <silent><buffer> <Plug>(gita-action-help-m)
        \ :<C-u>call gita#display#action('help', { 'name': 'status_mapping' })<CR>
  noremap <silent><buffer> <Plug>(gita-action-update)
        \ :<C-u>call gita#display#action('update')<CR>
  noremap <silent><buffer> <Plug>(gita-action-switch)
        \ :<C-u>call gita#display#action('open_commit')<CR>
  noremap <silent><buffer> <Plug>(gita-action-switch-new)
        \ :<C-u>call gita#display#action('open_commit', { 'amend': 0, 'new_commitmsg': 1 })<CR>
  noremap <silent><buffer> <Plug>(gita-action-switch-amend)
        \ :<C-u>call gita#display#action('open_commit', { 'amend': 1, 'new_commitmsg': 1 })<CR>
  noremap <silent><buffer> <Plug>(gita-action-open)
        \ :call gita#display#action('open')<CR>
  noremap <silent><buffer> <Plug>(gita-action-open-h)
        \ :call gita#display#action('open', { 'opener': 'split' })<CR>
  noremap <silent><buffer> <Plug>(gita-action-open-v)
        \ :call gita#display#action('open', { 'opener': 'vsplit' })<CR>
  noremap <silent><buffer> <Plug>(gita-action-add)
        \ :call gita#display#action('add')<CR>
  noremap <silent><buffer> <Plug>(gita-action-ADD)
        \ :call gita#display#action('add', { 'force': 1 })<CR>
  noremap <silent><buffer> <Plug>(gita-action-rm)
        \ :call gita#display#action('rm')<CR>
  noremap <silent><buffer> <Plug>(gita-action-RM)
        \ :call gita#display#action('rm', { 'force': 1 })<CR>
  noremap <silent><buffer> <Plug>(gita-action-reset)
        \ :call gita#display#action('reset')<CR>
  noremap <silent><buffer> <Plug>(gita-action-checkout)
        \ :call gita#display#action('checkout')<CR>
  noremap <silent><buffer> <Plug>(gita-action-CHECKOUT)
        \ :call gita#display#action('checkout', { 'force': 1 })<CR>
  noremap <silent><buffer> <Plug>(gita-action-checkout-ours)
        \ :call gita#display#action('checkout', { 'ours': 1 })<CR>
  noremap <silent><buffer> <Plug>(gita-action-checkout-theirs)
        \ :call gita#display#action('checkout', { 'theirs': 1 })<CR>
  noremap <silent><buffer> <Plug>(gita-action-stage)
        \ :call gita#display#action('stage')<CR>
  noremap <silent><buffer> <Plug>(gita-action-unstage)
        \ :call gita#display#action('unstage')<CR>
  noremap <silent><buffer> <Plug>(gita-action-toggle)
        \ :call gita#display#action('toggle')<CR>
  noremap <silent><buffer> <Plug>(gita-action-discard)
        \ :call gita#display#action('discard')<CR>

  " Define extra actual key mappings
  if get(g:, 'gita#features#status#enable_default_mappings', 1)
    nmap <buffer> q     :<C-u>q<CR>
    nmap <buffer> <C-l> <Plug>(gita-action-update)
    nmap <buffer> ?s    <Plug>(gita-action-help-s)
    nmap <buffer> ?m    <Plug>(gita-action-help-m)
    nmap <buffer> cc    <Plug>(gita-action-switch)
    nmap <buffer> cC    <Plug>(gita-action-switch-new)
    nmap <buffer> cA    <Plug>(gita-action-switch-amend)

    nmap <buffer><expr> e <SID>smart_map('e', '<Plug>(gita-action-open)')
    nmap <buffer><expr> E <SID>smart_map('E', '<Plug>(gita-action-open-v)')
    nmap <buffer><expr> <C-e> <SID>smart_map('<C-e>', '<Plug>(gita-action-open-h)')

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
    nmap <buffer><expr> -o <SID>smart_map('-o', '<Plug>(gita-action-checkout-ours)')
    nmap <buffer><expr> -t <SID>smart_map('-t', '<Plug>(gita-action-checkout-theirs)')

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
    vmap <buffer> -o <Plug>(gita-action-checkout-ours)
    vmap <buffer> -t <Plug>(gita-action-checkout-theirs)
  endif
  call gita#features#status#update()
  silent execute printf("setlocal filetype=%s", s:const.filetype)
endfunction " }}}
function! gita#features#status#update(...) abort " {{{
  let options = extend(
        \ deepcopy(w:_gita_options),
        \ get(a:000, 0, {}),
        \)
  let options.porcelain = 1
  let result = gita#features#status#exec(options, {
        \ 'echo': 'fail',
        \})
  if result.status != 0
    bwipe
    return
  endif
  let statuses = s:S.parse(result.stdout)
  let gita = gita#core#get()

  " create statuses lines & map
  let statuses_map = {}
  let statuses_lines = []
  for status in statuses.all
    call add(statuses_lines, status.record)
    let statuses_map[status.record] = status
  endfor
  let w:_gita_statuses_map = statuses_map

  " update content
  let buflines = s:L.flatten([
        \ ['# Press ?m and/or ?s to toggle a help of mapping and/or short format.'],
        \ gita#utils#help#get('status_mapping'),
        \ gita#utils#help#get('short_format'),
        \ s:get_status_header(gita),
        \ statuses_lines,
        \ empty(statuses_map) ? ['Nothing to commit (Working tree is clean).'] : [],
        \])
  call gita#utils#buffer#update(buflines)
endfunction " }}}
function! gita#features#status#command(bang, range, ...) abort " {{{
  let options = s:parser.parse(a:bang, a:range, get(a:000, 0, ''))
  if !empty(options)
    if get(options, 'window')
      call gita#features#status#open(options)
    else
      call gita#features#status#exec(options)
    endif
  endif
endfunction " }}}
function! gita#features#status#complete(arglead, cmdline, cursorpos) abort " {{{
  return s:parser.complete(a:arglead, a:cmdline, a:cursorpos)
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
let &cpo = s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
