"******************************************************************************
" vim-gita commit interface
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

  let lines = [
        \ '',
        \ '# Please enter the commit message for your changes. Lines starting',
        \ '# with "#" will be ignored, and an empty message aborts the commit.',
        \ '# On branch ' . local_branch,
        \]
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
  let line = substitute(getline('.'), '^#\s', '', 'g')
  let status = gita#utils#vital#GitStatusParser().parse_record(line, { 'fail_silently': 1 })
  echo status
  if empty(status)
    return
  endif
  "call call('s:action_' . a:action, [status, settings])
endfunction " }}}
function! s:action_diff(status, settings) " {{{
  echo "Not implemented yet"
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

function! gita#interface#commit#show(...) abort " {{{
  let bufname = s:get_buffer_name('commit')
  let settings = extend({
        \ 'opener': g:gita#interface#commit#opener,
        \ 'action_opener': g:gita#interface#commit#action_opener,
        \ 'openers': g:gita#interface#commit#openers,
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

      noremap <silent><buffer> <Plug>(gita-commit-action-diff)       :call <SID>action('diff')<CR>
      noremap <silent><buffer> <Plug>(gita-commit-action-browse)     :call <SID>action('browse')<CR>
      noremap <silent><buffer> <Plug>(gita-commit-action-open)       :call <SID>action('open')<CR>
      noremap <silent><buffer> <Plug>(gita-commit-action-edit)       :call <SID>action('open', 'edit')<CR>
      noremap <silent><buffer> <Plug>(gita-commit-action-split)      :call <SID>action('open', 'split')<CR>
      noremap <silent><buffer> <Plug>(gita-commit-action-vsplit)     :call <SID>action('open', 'vsplit')<CR>
      noremap <silent><buffer> <Plug>(gita-commit-action-tabnew)     :call <SID>action('open', 'tabnew')<CR>
      noremap <silent><buffer> <Plug>(gita-commit-action-open-left)  :call <SID>action('open', 'left')<CR>
      noremap <silent><buffer> <Plug>(gita-commit-action-open-right) :call <SID>action('open', 'right')<CR>
      noremap <silent><buffer> <Plug>(gita-commit-action-open-above) :call <SID>action('open', 'above')<CR>
      noremap <silent><buffer> <Plug>(gita-commit-action-open-below) :call <SID>action('open', 'below')<CR>

      if get(g:, 'gita#interface#commit#enable_default_keymaps', 1)
        nmap <buffer> <F1>   :<C-u>help vim-gita-commit-default-mappings<CR>
        nmap <buffer> <C-e>  <Plug>(gita-commit-action-open)
        nmap <buffer> <C-d>  <Plug>(gita-commit-action-diff)
        nmap <buffer> <C-s>  <Plug>(gita-commit-action-split)
        nmap <buffer> <C-v>  <Plug>(gita-commit-action-vsplit)
        nmap <buffer> <C-b>  <Plug>(gita-commit-action-browse)
        nmap <buffer> <CR>   <Plug>(gita-commit-action-open)
        nmap <buffer> <S-CR> <Plug>(gita-commit-action-diff)
        nmap <buffer> q      :<C-u>q<CR>
      endif
    endif
    " Load content
  else
    " focus window
    execute winnum . 'wincmd w'
  endif
  if bufnum != previous_bufnum
    let settings = get(b:, 'settings', {})
    let settings.previous_bufnum = previous_bufnum
  endif
endfunction " }}}
function! gita#interface#commit#update(...) abort " {{{
  let bufname = s:get_buffer_name('commit')
  let settings = extend({
        \ 'opener': g:gita#interface#commit#opener,
        \ 'action_opener': g:gita#interface#commit#action_opener,
        \ 'openers': g:gita#interface#commit#openers,
        \}, get(a:000, 0, gita#utils#getbufvar(bufname, 'settings', {})))
  " this function should be called on the gita:commit window
  if bufname !=# expand('%')
    call gita#utils#call_on_buffer(bufname,
          \ function('gita#interface#commit#update'),
          \ settings)
    return
  endif

  let Git = gita#utils#vital#Git()
  let statuslist = Git.get_status()
  if empty(statuslist) || empty(statuslist.all)
    bw!
    return
  endif

  " put gist lines
  let lines = s:get_header_lines()
  for status in statuslist.all
    call add(lines, '# ' . status.record)
  endfor

  echo lines

  " remove entire content and rewriet the lines
  setlocal modifiable
  let save_cur = getpos(".")
  silent %delete _
  call setline(1, lines)
  call setpos('.', [bufnr(bufname), 1, 1, 0]) "save_cur)
  setlocal nomodified

  " store variables to the buffer
  let b:settings = settings
endfunction " }}}
function! gita#interface#commit#define_highlights() abort " {{{
  highlight default link GitaCommitComment      Comment
  highlight default link GitaCommitConflicted   ErrorMsg
  highlight default link GitaCommitUnstaged     WarningMsg
  highlight default link GitaCommitStaged       Question
  highlight default link GitaCommitUntracked    WarningMsg
  highlight default link GitaCommitIgnored      Question
  highlight default link GitaCommitKeyword      Keyword
  highlight default link GitaCommitIssue        Identifier
  highlight default link GitaCommitBranch       Title
endfunction " }}}
function! gita#interface#commit#define_syntax() abort " {{{
  execute 'syntax match GitaCommitComment    /\v^#.*/'
  execute 'syntax match GitaCommitComment    /\v^# / contained'
  execute 'syntax match GitaCommitConflicted /\v^# %(DD|AU|UD|UA|DU|AA|UU)\s.*$/hs=s+2 contains=GitaCommitComment'
  execute 'syntax match GitaCommitUnstaged   /\v^# %([ MARC][MD]|DM)\s.*$/hs=s+2 contains=GitaCommitComment'
  execute 'syntax match GitaCommitStaged     /\v^# [MADRC] \s.*$/hs=s+2 contains=GitaCommitComment'
  execute 'syntax match GitaCommitUntracked  /\v^# \?\?\s.*$/hs=s+2 contains=GitaCommitComment'
  execute 'syntax match GitaCommitIgnored    /\v^# !!\s.*$/hs=s+2 contains=GitaCommitComment'
  " Branch name
  execute 'syntax match GitaCommitComment /\v^# On branch/ contained'
  execute 'syntax match GitaCommitBranch  /\v^# On branch .*$/hs=s+12 contains=GitaCommitComment'
  " GitHub keywords for closing issues
  execute 'syntax keyword GitaCommitKeyword close closes closed fix fixes fixed resolve resolves resolved'
  " GitHub issue format
  execute 'syntax match GitaCommitIssue "\v%([^ /#]+/[^ /#]+#\d+|#\d+)"'
endfunction " }}}

let s:consts = {}
let s:consts.DELIMITER = has('unix') ? ':' : '_'
let s:consts.FILETYPE = 'gita-commit'

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
    if !exists('g:gita#interface#commit#' . key)
      execute 'let g:gita#interface#commit#' . key . ' = ' . value
    endif
  endfor
  let g:gita#interface#commit#openers = extend(s:default_openers,
        \ get(g:, 'gita#interface#commit#openers', {}))
endfunction " }}}
call s:init()
" }}}

let &cpo = s:save_cpo
unlet s:save_cpo
"vim: sts=2 sw=2 smarttab et ai textwidth=0 fdm=marker
