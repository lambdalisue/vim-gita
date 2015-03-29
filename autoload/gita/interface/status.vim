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
function! s:action_conflict_2way(status, options) abort " {{{
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
  call gita#interface#conflict#2way(a:status, options)
endfunction " }}}
function! s:action_conflict_3way(status, options) abort " {{{
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
  call gita#interface#conflict#3way(a:status, options)
endfunction " }}}
function! s:action_add(statuses, options) abort " {{{
  let statuses = s:ensure_list(a:statuses)
  let options = extend({ 'force': 0 }, a:options)
  let result = s:get_gita().git.add(options, map(statuses, 'v:val.path'))
  if result.status == 0
    call s:update()
  else
    call gita#util#error(
          \ result.stdout,
          \ printf('Fail: %s', join(result.args)),
          \)
  endif
endfunction " }}}
function! s:action_rm(statuses, options) abort " {{{
  let statuses = s:ensure_list(a:statuses)
  let options = extend({ 'force': 0 }, a:options)
  let result = s:get_gita().git.rm(options, map(statuses, 'v:val.path'))
  if result.status == 0
    call s:update()
  else
    call gita#util#error(
          \ result.stdout,
          \ printf('Fail: %s', join(result.args)),
          \)
  endif
endfunction " }}}
function! s:action_reset(statuses, options) abort " {{{
  let statuses = s:ensure_list(a:statuses)
  let options = extend({
        \   'quiet': 1,
        \ }, a:options)
  let result = s:get_gita().git.reset(options, '', map(statuses, 'v:val.path'))
  if result.status == 0
    call s:update()
  else
    call gita#util#error(
          \ result.stdout,
          \ printf('Fail: %s', join(result.args)),
          \)
  endif
endfunction " }}}
function! s:action_checkout(statuses, options) abort " {{{
  let commit = gita#util#ask('Checkout from: ', 'HEAD')
  if strlen(commit) == 0
    redraw || call gita#util#warn('No valid commit was selected. The operation is canceled.')
    return
  endif
  let statuses = s:ensure_list(a:statuses)
  let options = extend({}, a:options)
  let result = s:get_gita().git.checkout(options, commit, map(statuses, 'v:val.path'))
  if result.status == 0
    call s:update()
  else
    call gita#util#error(
          \ result.stdout,
          \ printf('Fail: %s', join(result.args)),
          \)
  endif
endfunction " }}}
function! s:action_toggle(statuses, options) abort " {{{
  let statuses = s:ensure_list(a:statuses)
  let add_statuses = []
  let rm_statuses = []
  let reset_statuses = []
  for status in statuses
    if status.is_staged && status.is_unstaged
      if status.index ==# 'A' && status.worktree ==# 'D'
        call add(reset_statuses, status)
      else
        " TODO: think the behavior over again
        call add(add_statuses, status)
      endif
    elseif status.is_staged
        call add(reset_statuses, status)
    elseif status.index ==# ' ' && status.worktree ==# 'D'
        call add(rm_statuses, status)
    else
        call add(add_statuses, status)
    endif
  endfor
  if !empty(add_statuses)
    call s:action_add(add_statuses, a:options)
  endif
  if !empty(rm_statuses)
    call s:action_rm(rm_statuses, a:options)
  endif
  if !empty(reset_statuses)
    call s:action_reset(reset_statuses, a:options)
  endif
endfunction " }}}
function! s:action_discard(statuses, options) abort " {{{
  call gita#util#error('Not implemented yet.')
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
  autocmd QuitPre <buffer> call gita#util#invoker_focus()

  " define mappings
  call s:defmap()

  " update contents
  call s:update()
endfunction " }}}
function! s:defmap() abort " {{{
  nnoremap <silent><buffer> <Plug>(gita-action-help-m)   :<C-u>call <SID>action('help', { 'about': 'mappings' })<CR>
  nnoremap <silent><buffer> <Plug>(gita-action-help-s)   :<C-u>call <SID>action('help', { 'about': 'symbols' })<CR>

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
  nnoremap <silent><buffer> <Plug>(gita-action-conflict2-h) :<C-u>call <SID>action('conflict_2way', { 'opener': 'tabnew', 'vertical': 0 })<CR>
  nnoremap <silent><buffer> <Plug>(gita-action-conflict2-v) :<C-u>call <SID>action('conflict_2way', { 'opener': 'tabnew', 'vertical': 1 })<CR>
  nnoremap <silent><buffer> <Plug>(gita-action-conflict3-h) :<C-u>call <SID>action('conflict_3way', { 'opener': 'tabnew', 'vertical': 0 })<CR>
  nnoremap <silent><buffer> <Plug>(gita-action-conflict3-v) :<C-u>call <SID>action('conflict_3way', { 'opener': 'tabnew', 'vertical': 1 })<CR>

  nnoremap <silent><buffer> <Plug>(gita-action-add)      :<C-u>call <SID>action('add')<CR>
  nnoremap <silent><buffer> <Plug>(gita-action-ADD)      :<C-u>call <SID>action('add', { 'force': 1 })<CR>
  nnoremap <silent><buffer> <Plug>(gita-action-rm)       :<C-u>call <SID>action('rm')<CR>
  nnoremap <silent><buffer> <Plug>(gita-action-RM)       :<C-u>call <SID>action('RM', { 'force': 1 })<CR>
  nnoremap <silent><buffer> <Plug>(gita-action-reset)    :<C-u>call <SID>action('reset')<CR>
  nnoremap <silent><buffer> <Plug>(gita-action-checkout) :<C-u>call <SID>action('checkout')<CR>
  nnoremap <silent><buffer> <Plug>(gita-action-CHECKOUT) :<C-u>call <SID>action('checkout', { 'force': 1 })<CR>
  nnoremap <silent><buffer> <Plug>(gita-action-toggle)   :<C-u>call <SID>action('toggle')<CR>
  nnoremap <silent><buffer> <Plug>(gita-action-TOGGLE)   :<C-u>call <SID>action('toggle', { 'force': 1 })<CR>
  nnoremap <silent><buffer> <Plug>(gita-action-discard)  :<C-u>call <SID>action('discard')<CR>

  vnoremap <silent><buffer> <Plug>(gita-action-add)      :<C-u>call <SID>action('add', 1)<CR>
  vnoremap <silent><buffer> <Plug>(gita-action-ADD)      :<C-u>call <SID>action('add', 1, { 'force': 1 })<CR>
  vnoremap <silent><buffer> <Plug>(gita-action-rm)       :<C-u>call <SID>action('rm', 1)<CR>
  vnoremap <silent><buffer> <Plug>(gita-action-RM)       :<C-u>call <SID>action('RM', 1, { 'force': 1 })<CR>
  vnoremap <silent><buffer> <Plug>(gita-action-reset)    :<C-u>call <SID>action('reset', 1)<CR>
  vnoremap <silent><buffer> <Plug>(gita-action-checkout) :<C-u>call <SID>action('checkout', 1)<CR>
  vnoremap <silent><buffer> <Plug>(gita-action-CHECKOUT) :<C-u>call <SID>action('checkout', 1, { 'force': 1 })<CR>
  vnoremap <silent><buffer> <Plug>(gita-action-toggle)   :<C-u>call <SID>action('toggle', 1)<CR>
  vnoremap <silent><buffer> <Plug>(gita-action-TOGGLE)   :<C-u>call <SID>action('toggle', 1, { 'force': 1 })<CR>
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
    nmap <buffer><expr> c  <SID>smart_map('c', '<Plug>(gita-action-conflict2-v)')
    nmap <buffer><expr> C  <SID>smart_map('C', '<Plug>(gita-action-conflict3-v)')

    nmap <buffer><expr> -- <SID>smart_map('--', '<Plug>(gita-action-toggle)')
    nmap <buffer><expr> >> <SID>smart_map('>>', '<Plug>(gita-action-unstage)')
    nmap <buffer><expr> -= <SID>smart_map('-=', '<Plug>(gita-action-TOGGLE)')
    nmap <buffer><expr> -a <SID>smart_map('-a', '<Plug>(gita-action-add)')
    nmap <buffer><expr> -A <SID>smart_map('-A', '<Plug>(gita-action-ADD)')
    nmap <buffer><expr> -r <SID>smart_map('-r', '<Plug>(gita-action-rm)')
    nmap <buffer><expr> -R <SID>smart_map('-R', '<Plug>(gita-action-RM)')
    nmap <buffer><expr> -c <SID>smart_map('-c', '<Plug>(gita-action-checkout)')
    nmap <buffer><expr> -C <SID>smart_map('-C', '<Plug>(gita-action-CHECKOUT)')
    nmap <buffer><expr> -d <SID>smart_map('-d', '<Plug>(gita-action-discard)')
    nmap <buffer><expr> -D <SID>smart_map('-D', '<Plug>(gita-action-discard)')

    vmap <buffer> -- <Plug>(gita-action-toggle)
    vmap <buffer> -= <Plug>(gita-action-TOGGLE)
    vmap <buffer> -a <Plug>(gita-action-add)
    vmap <buffer> -A <Plug>(gita-action-ADD)
    vmap <buffer> -r <Plug>(gita-action-reset)
    vmap <buffer> -R <Plug>(gita-action-reset)
    vmap <buffer> -c <Plug>(gita-action-checkout)
    vmap <buffer> -C <Plug>(gita-action-CHECKOUT)
    vmap <buffer> -d <Plug>(gita-action-discard)
    vmap <buffer> -D <Plug>(gita-action-discard)
  endif
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
        \ ['# Press ?m and/or ?s to toggle a help of mappings and/or status symbols.'],
        \ get(b:, '_help_mappings', 0) ? ['# -- Mapping --'] : [],
        \ get(b:, '_help_symbols', 0)  ? ['# -- Symbols --'] : [],
        \ gita#util#interface_get_misc_lines(),
        \ statuses_lines,
        \ empty(statuses_map) ? ['Nothing to commit (Working tree is clean).'] : [],
        \])

  " update content
  setlocal modifiable
  call gita#util#buffer_update(buflines)
  setlocal nomodifiable
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
function! gita#interface#status#define_highlights() abort " {{{
  highlight default link GitaComment    Comment
  highlight default link GitaConflicted ErrorMsg
  highlight default link GitaUnstaged   WarningMsg
  highlight default link GitaStaged     Question
  highlight default link GitaUntracked  WarningMsg
  highlight default link GitaIgnored    Question
  highlight default link GitaBranch     Title
endfunction " }}}
function! gita#interface#status#define_syntax() abort " {{{
  execute 'syntax match GitaConflicted /\v^%(DD|AU|UD|UA|DU|AA|UU)\s.*$/'
  execute 'syntax match GitaUnstaged   /\v^%([ MARC][MD]|DM)\s.*$/'
  execute 'syntax match GitaStaged     /\v^[MADRC]\s\s.*$/'
  execute 'syntax match GitaUntracked  /\v^\?\?\s.*$/'
  execute 'syntax match GitaIgnored    /\v^!!\s.*$/'
  execute 'syntax match GitaBranch  /\v`[^`]{-}`/hs=s+1,he=e-1'
  execute 'syntax match GitaComment /\v^#.*/ contains=GitaBranch'
endfunction " }}}

let &cpo = s:save_cpo
unlet! s:save_cpo
"vim: stts=2 sw=2 smarttab et ai textwidth=0 fdm=marker

