"******************************************************************************
" vim-gita interface/commit
"
" Author:   Alisue <lambdalisue@hashnote.net>
" URL:      http://hashnote.net/
" License:  MIT license
" (C) 2015, Alisue, hashnote.net
"******************************************************************************
let s:save_cpo = &cpo
set cpo&vim

let s:const = {}
let s:const.bufname  = has('unix') ? 'gita:commit' : 'gita_commit'
let s:const.filetype = 'gita-commit'

let s:Prelude = gita#util#import('Prelude')
let s:List = gita#util#import('Data.List')

function! s:ensure_list(x) abort " {{{
  return s:Prelude.is_list(a:x) ? a:x : [a:x]
endfunction " }}}
function! s:get_gita(...) abort " {{{
  let gita = call('gita#get', a:000)
  let gita.interface = get(gita, 'interface', {})
  let gita.interface.commit = get(gita.interface, 'commit', {})
  return gita
endfunction " }}}
function! s:get_selected_status() abort " {{{
  let gita = s:get_gita()
  let statuses_map = get(gita.interface.commit, 'statuses_map', {})
  let selected_line = getline('.')
  return get(statuses_map, selected_line, {})
endfunction " }}}
function! s:get_selected_statuses() abort " {{{
  let gita = s:get_gita()
  let statuses_map = get(gita.interface.commit, 'statuses_map', {})
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
function! s:get_current_commitmsg() abort " {{{
  return filter(getline(1, '$'), 'v:val !~# "^#"')
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
function! s:action_open_status(status, options) abort " {{{
  let gita = s:get_gita()
  if &modified
    let gita = s:get_gita()
    let gita.interface.commit.commitmsg_cached = s:get_current_commitmsg()
    setlocal nomodified
  endif
  call gita#interface#status#open(a:options)
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
function! s:action_diff(status, options) abort " {{{
  call gita#util#error('Not implemented yet.')
endfunction " }}}
function! s:action_commit(status, options) abort " {{{
  if s:validate_filetype('s:action_commit()')
    return
  endif
  let gita = s:get_gita()
  let meta = gita.git.get_meta()
  let options = extend({ 'force': 0 }, a:options)
  let statuses_map = get(gita.interface.commit, 'statuses_map', {})
  if empty(meta.merge_head) && empty(filter(values(statuses_map), 'v:val.is_staged'))
    " nothing to be committed
    return
  elseif &modified
    redraw | call gita#util#warn(
          \ 'You have unsaved changes on the commit message. Save the changes by ":w" command.',
          \ 'Unsaved changes exists'
          \)
    return
  endif

  let commitmsg = s:get_current_commitmsg()
  if join(commitmsg, '') =~# '\v^\s*$'
    redraw | call gita#util#info(
          \ 'No commit message is available (all lines start from "#" are truncated). The operation has canceled.',
          \ 'Commit message does not exist'
          \)
    return
  endif

  " commit
  let options.file = tempname()
  call writefile(commitmsg, options.file)
  let result = gita.git.commit(options)
  if result.status != 0
    redraw | call gita#util#error(
          \ result.stdout,
          \ printf('Fail: %s', join(result.args)),
          \)
    return
  endif

  call gita#util#doautocmd('commit-post')
  " clear
  let gita.interface.commit = {}
  let gita.interface.commit.use_empty_commitmsg_next = 1
  let b:_options = {}
  if get(options, 'quitting', 0)
    call s:update()
  endif
  call gita#util#info(
        \ result.stdout,
        \ printf('Ok: %s', join(result.args)),
        \)
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
  setlocal buftype=acwrite bufhidden=hide noswapfile nobuflisted
  setlocal winfixheight

  autocmd! * <buffer>
  autocmd BufWriteCmd <buffer> call s:ac_write(expand('<amatch>'))
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
function! s:defmap() abort " {{{
  nnoremap <silent><buffer> <Plug>(gita-action-help-m)   :<C-u>call <SID>action('help', { 'about': 'commit_mapping' })<CR>
  nnoremap <silent><buffer> <Plug>(gita-action-help-s)   :<C-u>call <SID>action('help', { 'about': 'short_format' })<CR>

  nnoremap <silent><buffer> <Plug>(gita-action-update)   :<C-u>call <SID>action('update')<CR>
  nnoremap <silent><buffer> <Plug>(gita-action-switch)   :<C-u>call <SID>action('open_status')<CR>
  nnoremap <silent><buffer> <Plug>(gita-action-commit)   :<C-u>call <SID>action('commit')<CR>
  nnoremap <silent><buffer> <Plug>(gita-action-COMMIT)   :<C-u>call <SID>action('commit', { 'force(: 1 })<CR>
  nnoremap <silent><buffer> <Plug>(gita-action-open)     :<C-u>call <SID>action('open', { 'opener': 'edit' })<CR>
  nnoremap <silent><buffer> <Plug>(gita-action-open-h)   :<C-u>call <SID>action('open', { 'opener': 'botright split' })<CR>
  nnoremap <silent><buffer> <Plug>(gita-action-open-v)   :<C-u>call <SID>action('open', { 'opener': 'botright vsplit' })<CR>
  nnoremap <silent><buffer> <Plug>(gita-action-open-s)   :<C-u>call <SID>action('open', { 'opener': 'select' })<CR>
  nnoremap <silent><buffer> <Plug>(gita-action-diff)     :<C-u>call <SID>action('diff', { 'opener': 'edit' })<CR>
  nnoremap <silent><buffer> <Plug>(gita-action-diff-h)   :<C-u>call <SID>action('diff', { 'opener': 'botright split' })<CR>
  nnoremap <silent><buffer> <Plug>(gita-action-diff-v)   :<C-u>call <SID>action('diff', { 'opener': 'botright vsplit' })<CR>

  " aliases (long name)
  nmap <buffer> <Plug>(gita-action-help-mappings)   <Plug>(gita-action-help-m)
  nmap <buffer> <Plug>(gita-action-help-symbols)    <Plug>(gita-action-help-s)
  nmap <buffer> <Plug>(gita-action-open-horizontal) <Plug>(gita-action-open-h)
  nmap <buffer> <Plug>(gita-action-open-vertical)   <Plug>(gita-action-open-v)
  nmap <buffer> <Plug>(gita-action-open-select)     <Plug>(gita-action-open-s)
  nmap <buffer> <Plug>(gita-action-diff-horizontal) <Plug>(gita-action-diff-h)
  nmap <buffer> <Plug>(gita-action-diff-vertical)   <Plug>(gita-action-diff-v)

  if get(g:, 'gita#interface#commit#enable_default_keymap', 1)
    nmap <buffer><silent> q  :<C-u>quit<CR>
    nmap <buffer> <C-l> <Plug>(gita-action-update)
    nmap <buffer> ?m <Plug>(gita-action-help-m)
    nmap <buffer> ?s <Plug>(gita-action-help-s)

    nmap <buffer> cc <Plug>(gita-action-switch)
    nmap <buffer> CC <Plug>(gita-action-commit)

    nmap <buffer><expr> e <SID>smart_map('e', '<Plug>(gita-action-open)')
    nmap <buffer><expr> E <SID>smart_map('E', '<Plug>(gita-action-open-v)')
    nmap <buffer><expr> s <SID>smart_map('s', '<Plug>(gita-action-open-s)')
    nmap <buffer><expr> d <SID>smart_map('d', '<Plug>(gita-action-diff)')
    nmap <buffer><expr> D <SID>smart_map('D', '<Plug>(gita-action-diff-v)')
  endif
endfunction " }}}
function! s:update(...) abort " {{{
  let gita = s:get_gita()
  let meta = gita.git.get_meta({ 'no_cache': 1 })
  let options = extend(b:_options, get(a:000, 0, {}))
  let result = gita.git.get_parsed_commit(
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
    let line = printf('# %s', status.record)
    call add(statuses_lines, line)
    let statuses_map[line] = status
  endfor
  let gita.interface.commit.statuses_map = statuses_map

  " create a default commit message
  let modified_reserved = 0
  if get(gita.interface.commit, 'use_empty_commitmsg_next', 0)
    let commitmsg = []
    unlet! gita.interface.commit.use_empty_commitmsg_next
  elseif has_key(gita.interface.commit, 'commitmsg_cached')
    let commitmsg = gita.interface.commit.commitmsg_cached
    let modified_reserved = 1
    unlet! gita.interface.commit.commitmsg_cached
  elseif has_key(gita.interface.commit, 'commitmsg')
    let commitmsg = gita.interface.commit.commitmsg
  elseif !empty(meta.merge_head)
    let commitmsg = [
          \ meta.merge_msg,
          \]
  elseif get(options, 'amend', 0)
    let commitmsg = [
          \ gita.git.get_last_commitmsg(),
          \]
  else
    let commitmsg = s:get_current_commitmsg()
  endif

  " create buffer lines
  let buflines = s:List.flatten([
        \ commitmsg,
        \ ['# Press ?m and/or ?s to toggle a help of mapping and/or short format.'],
        \ s:get_help('commit_mapping'),
        \ s:get_help('short_format'),
        \ gita#util#interface_get_misc_lines(),
        \ !empty(meta.merge_msg) ? ['# This branch is in MERGE mode.'] : [],
        \ get(options, 'amend', 0) ? ['# This branch is in AMEND mode.'] : [],
        \ statuses_lines,
        \])
  let buflines = buflines[0] =~# '\v^#' ? extend([''], buflines) : buflines

  " update content
  setlocal modifiable
  call gita#util#buffer_update(buflines)

  if modified_reserved
    setlocal modified
  endif
endfunction " }}}
function! s:ac_write(filename) abort " {{{
  if a:filename != expand('%:p')
    " a new filename is given. save the content to the new file
    execute 'w' . (v:cmdbang ? '!' : '') fnameescape(v:cmdarg) fnameescape(a:filename)
    return
  endif
  " cache commitmsg
  let gita = s:get_gita()
  let gita.interface.commit.commitmsg = s:get_current_commitmsg()
  setlocal nomodified
endfunction " }}}
function! s:ac_quit(...) abort " {{{
  let options = deepcopy(b:_options)
  let options.quitting = 1
  call s:action_commit({}, options)
  call gita#util#invoker_focus()
endfunction " }}}

" Public API
function! gita#interface#commit#open(...) abort " {{{
  call call('s:open', a:000)
endfunction " }}}
function! gita#interface#commit#update(...) abort " {{{
  if bufname('%') !=# s:const.bufname
    call call('s:open', a:000)
  else
    call call('s:update', a:000)
  endif
endfunction " }}}
function! gita#interface#commit#action(name, ...) abort " {{{
  if s:validate_filetype('gita#interface#commit#action()')
    return
  endif
  call call('s:action', extend([a:name], a:000))
endfunction " }}}
function! gita#interface#commit#smart_map(lhs, rhs) abort " {{{
  if s:validate_filetype('gita#interface#commit#smart_map()')
    return
  endif
  call call('s:smart_map', [a:lhs, a:rhs])
endfunction " }}}
function! gita#interface#commit#define_highlights() abort " {{{
  highlight default link GitaComment    Comment
  highlight default link GitaConflicted Error
  highlight default link GitaStaged     Special
  highlight default link GitaUnstaged   Constant
  highlight default link GitaUntracked  GitaUnstaged
  highlight default link GitaIgnored    Identifier
  highlight default link GitaBranch     Title
  highlight default link GitaImportant  Tag
  " github
  highlight default link GitaGitHubKeyword Keyword
  highlight default link GitaGitHubIssue   Define
endfunction " }}}
function! gita#interface#commit#define_syntax() abort " {{{
  syntax match GitaStaged     /\v^# [ MADRC][ MD]/hs=s+2,he=e-1 contains=ALL
  syntax match GitaUnstaged   /\v^# [ MADRC][ MD]/hs=s+3 contains=ALL
  syntax match GitaStaged     /\v^# [ MADRC]\s.*$/hs=s+5 contains=ALL
  syntax match GitaUnstaged   /\v^# .[MDAU?].*$/hs=s+5 contains=ALL
  syntax match GitaIgnored    /\v^# \!\!\s.*$/hs=s+2
  syntax match GitaUntracked  /\v^# \?\?\s.*$/hs=s+2
  syntax match GitaConflicted /\v^# %(DD|AU|UD|UA|DU|AA|UU)\s.*$/hs=s+2
  syntax match GitaComment    /\v^#.*$/ contains=ALL
  syntax match GitaBranch     /\v`[^`]{-}`/hs=s+1,he=e-1
  syntax keyword GitaImportant AMEND MERGE
  " github
  syntax keyword GitaGitHubKeyword close closes closed fix fixes fixed resolve resolves resolved
  syntax match   GitaGitHubIssue   '\v%([^ /#]+/[^ /#]+#\d+|#\d+)'
endfunction " }}}
let &cpo = s:save_cpo
unlet! s:save_cpo
"vim: stts=2 sw=2 smarttab et ai textwidth=0 fdm=marker


