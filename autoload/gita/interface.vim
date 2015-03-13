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
  let b = substitute(s:Git.get_branch_name(), '\v^"|"$', '', 'g')
  let r = substitute(s:Git.get_remote_branch_name(), '\v^"|"$', '', 'g')
  let o = s:Git.count_outgoing()
  let i = s:Git.count_incoming()

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
    call b:gita.set('invoker_bufnum', invoker_bufnum)
    call b:gita.set('invoker_winnum', bufwinnr(invoker_bufnum))
    return
  endif
  let b:gita = s:Cache.new()
  call b:gita.set('invoker_bufnum', invoker_bufnum)
  call b:gita.set('invoker_winnum', bufwinnr(invoker_bufnum))

  " construction
  setlocal buftype=nofile bufhidden=hide noswapfile nobuflisted
  setlocal textwidth=0
  setlocal cursorline
  setlocal winfixheight
  execute 'setfiletype' s:const.status_filetype

  nnoremap <silent><buffer> <Plug>(gita-action-update)      :<C-u>call <SID>status_action('update')<CR>
  nnoremap <silent><buffer> <Plug>(gita-action-toggle)      :<C-u>call <SID>status_action('toggle')<CR>
  nnoremap <silent><buffer> <Plug>(gita-action-revert)      :<C-u>call <SID>status_action('revert')<CR>
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
  vnoremap <silent><buffer> <Plug>(gita-action-update)      :call <SID>status_action('update')<CR>
  vnoremap <silent><buffer> <Plug>(gita-action-toggle)      :call <SID>status_action('toggle')<CR>
  vnoremap <silent><buffer> <Plug>(gita-action-revert)      :call <SID>status_action('revert')<CR>

  " alias
  nmap <silent><buffer> <Plug>(gita-action-open) <Plug>(gita-action-open-edit)
  nmap <silent><buffer> <Plug>(gita-action-diff) <Plug>(gita-action-diff-vsplit)

  if get(g:, 'gita#interface#enable_default_keymaps', 1)
    nmap <buffer> q      :<C-u>q<CR>
    nmap <buffer> <C-l>  <Plug>(gita-action-update)
    nmap <buffer> -      <Plug>(gita-action-toggle)
    nmap <buffer> R      <Plug>(gita-action-revert)
    nmap <buffer> <CR>   <Plug>(gita-action-open)
    nmap <buffer> <S-CR> <Plug>(gita-action-diff)
    nmap <buffer> <C-e>  <Plug>(gita-action-open)
    nmap <buffer> <C-d>  <Plug>(gita-action-diff)
    nmap <buffer> <C-s>  <Plug>(gita-action-open-split)
    nmap <buffer> <C-v>  <Plug>(gita-action-open-vsplit)
    vmap <buffer> -      <Plug>(gita-action-toggle)
  endif

  " automatically focus invoker when the buffer is closed
  autocmd! * <buffer>
  autocmd QuitPre <buffer> call s:invoker_focus(b:gita)

  " update contents
  call s:status_update()
endfunction " }}}
function! s:status_update() abort " {{{
  if &filetype != s:const.status_filetype
    throw 'vim-gita: s:status_update required to be executed on a proper buffer'
  endif

  let status = s:Git.get_status()
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
  silent %delete _
  call setline(1, buflines)
  call setpos('.', saved_cur)
  setlocal nomodified
  setlocal nomodifiable

  call b:gita.set('status_map', status_map)
  call b:gita.set('status', status)
endfunction " }}}
function! s:status_action(name, ...) abort " {{{
  if &filetype != s:const.status_filetype
    throw 'vim-gita: s:status_action required to be executed on a proper buffer'
  endif
  let opener = get(g:gita#interface#opener_aliases, get(a:000, 0, ''), '')
  let status_map = b:gita.get('status_map', {})
  let selected_line = getline('.')
  let selected_status = get(status_map, selected_line, {})
  if empty(selected_status)
    " the action is executed on invalid line so just do nothing
    return
  endif
  let fname = printf('s:status_action_%s', a:name)
  call call(fname, [selected_status, opener])
endfunction " }}}
function! s:status_action_update(status, opener) abort " {{{
  call s:status_update()
  redraw!
endfunction " }}}
function! s:status_action_toggle(status, opener) abort " {{{
  if a:status.is_conflicted || a:status.is_ignored
    return
  elseif a:status.is_unstaged
    if a:status.worktree == 'D'
      call gita#action#rm(['--', a:status.path])
    else
      call gita#action#add(['--', a:status.path])
    endif
  elseif a:status.is_untracked
    call gita#action#add(['--', a:status.path])
  else
    call gita#action#rm(['--cached', '--', a:status.path])
  endif
  call s:status_update()
endfunction " }}}
function! s:status_action_revert(status, opener) abort " {{{
  call gita#util#error('the action has not been implemented yet.', 'Not implemented error:')
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


" Public
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

