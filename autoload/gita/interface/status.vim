"******************************************************************************
" vim-gita status interface
"
" Author:   Alisue <lambdalisue@hashnote.net>
" URL:      http://hashnote.net/
" License:  MIT license
" (C) 2015, Alisue, hashnote.net
"******************************************************************************
let s:save_cpo = &cpo
set cpo&vim


function! s:get_buffer_name(...) abort " {{{
  return 'gita' . s:consts.DELIMITER . gita#utils#vital#Path().join(a:000)
endfunction " }}}
function! s:get_header_lines() abort " {{{
  let Git = gita#utils#vital#Git()
  let local_branch = Git.get_branch_name()
  let remote_branch = Git.get_remote_branch_name()
  let incoming = Git.count_incoming()
  let outgoing = Git.count_outgoing()

  let lines = ['# On branch ' . local_branch]
  if incoming > 0 && outgoing > 0
    call add(lines,
          \ printf(
          \   '# This branch is %d commit(s) ahead of and %d commit(s) behind %s',
          \   outgoing, incoming, remote_branch
          \ ))
  elseif incoming > 0
    call add(lines,
          \ printf(
          \   '# This branch is %d commit(s) behind %s',
          \   incoming, remote_branch
          \ ))
  elseif outgoing > 0
    call add(lines,
          \ printf(
          \   '# This branch is %d commit(s) ahead of %s',
          \   outgoing, remote_branch
          \ ))
  endif
  return lines
endfunction " }}}
function! s:action(action, ...) abort " {{{
  if &filetype !=# s:consts.FILETYPE
    return
  endif
  let settings = extend(b:settings, {
        \ 'action_opener': get(a:000, 0, b:settings.action_opener),
        \})
  let linelinks = b:linelinks
  let status = get(linelinks, line('.') - 1, {})
  if empty(status)
    return
  endif
  call call('s:action_' . a:action, [status, settings])
endfunction " }}}
function! s:action_update(status, settings) " {{{
  call gita#interface#status#update()
endfunction " }}}
function! s:action_toggle(status, settings) " {{{
  let Git = gita#utils#vital#Git()
  if a:status.is_unstaged || a:status.is_untracked
    call Git.add(a:status.path)
  elseif a:status.is_staged
    call Git.rm(a:status.path, ['--cached'])
  endif
  call gita#interface#status#update()
endfunction " }}}
function! s:action_diff(status, settings) " {{{
  echo "Not implemented yet"
endfunction " }}}
function! s:action_clear(status, settings) " {{{
  let Git = gita#utils#vital#Git()
  if a:status.is_untracked
    redraw
    echohl GitaWarning
    echo  'Remove the untracked "' . a:status.path . '":'
    echohl None
    echo  'This operation will remove the untracked file and could not be reverted.'
    echohl GitaQuestion
    let a = gita#utils#input_yesno(
          \ 'Are you sure that you want to remove the untracked file?')
    echohl None
    if a
      call delete(a:status.path)
    endif
  else
    redraw
    echohl GitaWarning
    echo  'Discard the local changes on "' . a:status.path . '":'
    echohl None
    echo  'This operation will discard the local changes on the file and revert it to the latest commit.'
    echohl GitaQuestion
    let a = gita#utils#input_yesno(
          \ 'Are you sure that you want to discard the local changes?')
    echohl None
    if a
      call Git.checkout(a:status.path, ['HEAD'])
    endif
  endif
  call gita#interface#status#update()
endfunction " }}}
function! s:action_open(status, settings) " {{{
  let opener = get(
        \ a:settings.openers,
        \ a:settings.action_opener,
        \ a:settings.action_opener
        \)
  let bufname = get(a:status, 'path2', a:status.path)
  let bufnum = bufnr(bufname)
  let winnum = bufwinnr(bufnum)

  if winnum == -1
    let previous_winnum = bufwinnr(get(a:settings, 'previous_bufnum'))
    if previous_winnum != -1
      execute previous_winnum . 'wincmd w'
    else
      execute 'wincmd p'
    endif
    call gita#utils#vital#Buffer().open(bufname, opener)
  else
    execute winnum . 'wincmd w'
  endif
endfunction " }}}
function! s:action_browse(status, settings) " {{{
  echo "Not implemented yet"
endfunction " }}}

function! gita#interface#status#show(...) abort " {{{
  let bufname = s:get_buffer_name('status')
  let settings = extend({
        \ 'opener': g:gita#interface#status#opener,
        \ 'action_opener': g:gita#interface#status#action_opener,
        \ 'openers': g:gita#interface#status#openers,
        \}, get(a:000, 0, {}))

  let opener = get(settings.openers, settings.opener, settings.opener)
  let bufnum = bufnr(bufname)
  let winnum = bufwinnr(bufnum)
  let previous_bufnum = bufnr('')
  if winnum == -1
    call gita#utils#vital#Buffer().open(bufname, opener)
    if bufnum == -1
      " initialize list window
      setlocal buftype=nofile bufhidden=hide noswapfile nobuflisted
      setlocal cursorline
      execute "setfiletype" s:consts.FILETYPE

      noremap <silent><buffer> <Plug>(gita-status-action-update)     :call <SID>action('update')<CR>
      noremap <silent><buffer> <Plug>(gita-status-action-toggle)     :call <SID>action('toggle')<CR>
      noremap <silent><buffer> <Plug>(gita-status-action-diff)       :call <SID>action('diff')<CR>
      noremap <silent><buffer> <Plug>(gita-status-action-clear)      :call <SID>action('clear')<CR>
      noremap <silent><buffer> <Plug>(gita-status-action-browse)     :call <SID>action('browse')<CR>
      noremap <silent><buffer> <Plug>(gita-status-action-open)       :call <SID>action('open')<CR>
      noremap <silent><buffer> <Plug>(gita-status-action-edit)       :call <SID>action('open', 'edit')<CR>
      noremap <silent><buffer> <Plug>(gita-status-action-split)      :call <SID>action('open', 'split')<CR>
      noremap <silent><buffer> <Plug>(gita-status-action-vsplit)     :call <SID>action('open', 'vsplit')<CR>
      noremap <silent><buffer> <Plug>(gita-status-action-tabnew)     :call <SID>action('open', 'tabnew')<CR>
      noremap <silent><buffer> <Plug>(gita-status-action-open-left)  :call <SID>action('open', 'left')<CR>
      noremap <silent><buffer> <Plug>(gita-status-action-open-right) :call <SID>action('open', 'right')<CR>
      noremap <silent><buffer> <Plug>(gita-status-action-open-above) :call <SID>action('open', 'above')<CR>
      noremap <silent><buffer> <Plug>(gita-status-action-open-below) :call <SID>action('open', 'below')<CR>

      if get(g:, 'gita#interface#status#enable_default_keymaps', 1)
        nmap <buffer> <F1>   :<C-u>help vim-gita-status-default-mappings<CR>
        nmap <buffer> <C-l>  <Plug>(gita-status-action-update)
        nmap <buffer> -      <Plug>(gita-status-action-toggle)
        nmap <buffer> <C-c>  <Plug>(gita-status-action-clear)
        nmap <buffer> <C-e>  <Plug>(gita-status-action-open)
        nmap <buffer> <C-d>  <Plug>(gita-status-action-diff)
        nmap <buffer> <C-s>  <Plug>(gita-status-action-split)
        nmap <buffer> <C-v>  <Plug>(gita-status-action-vsplit)
        nmap <buffer> <C-b>  <Plug>(gita-status-action-browse)
        nmap <buffer> <CR>   <Plug>(gita-status-action-open)
        nmap <buffer> <S-CR> <Plug>(gita-status-action-diff)
        nmap <buffer> q      :<C-u>q<CR>
        vmap <buffer> -      <Plug>(gita-status-action-toggle)
      endif
      " load contents
      call gita#interface#status#update(settings)
    endif
  else
    " focus window
    execute winnum . 'wincmd w'
  endif
  if bufnum != previous_bufnum
    let settings = get(b:, 'settings', {})
    let settings.previous_bufnum = previous_bufnum
  endif
endfunction " }}}
function! gita#interface#status#update(...) abort " {{{
  let bufname = s:get_buffer_name('status')
  let settings = extend({
        \ 'opener': g:gita#interface#status#opener,
        \ 'action_opener': g:gita#interface#status#action_opener,
        \ 'openers': g:gita#interface#status#openers,
        \}, get(a:000, 0, gita#utils#getbufvar(bufname, 'settings', {})))
  " this function should be called on the gita:status window
  if bufname !=# expand('%')
    call gita#utils#call_on_buffer(bufname,
          \ function('gita#interface#status#update'),
          \ settings)
    return
  endif

  let Git = gita#utils#vital#Git()
  let statuslist = Git.get_status()
  if empty(statuslist) || empty(statuslist.all)
    bw!
    return
  endif

  " put gist lines and links
  let lines = s:get_header_lines()
  let linelinks = []
  for line in lines
    call add(linelinks, {})
  endfor
  for status in statuslist.all
    call add(lines, status.record)
    call add(linelinks, status)
  endfor

  " remove entire content and rewriet the lines
  setlocal modifiable
  let save_cur = getpos(".")
  silent %delete _
  call setline(1, split(join(lines, "\n"), "\n"))
  call setpos('.', save_cur)
  setlocal nomodifiable
  setlocal nomodified

  " store variables to the buffer
  let b:settings = settings
  let b:linelinks = linelinks
endfunction " }}}
function! gita#interface#status#define_highlights() abort " {{{
  highlight default link GitaStatusComment      Comment
  highlight default link GitaStatusConflicted   ErrorMsg
  highlight default link GitaStatusUnstaged     WarningMsg
  highlight default link GitaStatusStaged       Question
  highlight default link GitaStatusUntracked    WarningMsg
  highlight default link GitaStatusIgnored      Question
  highlight default link GitaStatusBranch       Title
endfunction " }}}
function! gita#interface#status#define_syntax() abort " {{{
  execute 'syntax match GitaStatusComment    /\v^#.*/'
  execute 'syntax match GitaStatusConflicted /\v^%(DD|AU|UD|UA|DU|AA|UU)\s.*\ze/'
  execute 'syntax match GitaStatusUnstaged   /\v^%([ MARC][MD]|DM)\s.*\ze/'
  execute 'syntax match GitaStatusStaged     /\v^[MADRC]\s\s.*\ze/'
  execute 'syntax match GitaStatusUntracked  /\v^\?\?\s.*\ze/'
  execute 'syntax match GitaStatusIgnored    /\v^!!\s.*\ze/'
  " Branch name
  execute 'syntax match GitaStatusComment /\v^# On branch/ contained'
  execute 'syntax match GitaStatusBranch  /\v^# On branch .*$/hs=s+12 contains=GitaStatusComment'
endfunction " }}}

let s:consts = {}
let s:consts.DELIMITER = has('unix') ? ':' : '_'
let s:consts.FILETYPE = 'gita-status'

" Variables {{{
let s:default_openers = {
      \ 'edit': 'edit',
      \ 'tabnew': 'tabnew',
      \ 'split': 'rightbelow split',
      \ 'vsplit': 'rightbelow vsplit',
      \ 'left': 'topleft vsplit', 
      \ 'right': 'rightbelow vsplit', 
      \ 'above': 'topleft split', 
      \ 'below': 'rightbelow split', 
      \}
let s:settings = {
      \ 'opener': '"topleft 20 split +set\\ winfixheight"',
      \ 'action_opener': '"edit"',
      \ 'enable_default_keymaps': 1,
      \}
function! s:init() " {{{
  for [key, value] in items(s:settings)
    if !exists('g:gita#interface#status#' . key)
      execute 'let g:gita#interface#status#' . key . ' = ' . value
    endif
  endfor
  let g:gita#interface#status#openers = extend(s:default_openers,
        \ get(g:, 'gita#interface#status#openers', {}))
endfunction " }}}
call s:init()
" }}}

let &cpo = s:save_cpo
unlet s:save_cpo
"vim: sts=2 sw=2 smarttab et ai textwidth=0 fdm=marker
