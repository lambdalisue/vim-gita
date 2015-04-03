"******************************************************************************
" vim-gita interface/conflict
"
" Author:   Alisue <lambdalisue@hashnote.net>
" URL:      http://hashnote.net/
" License:  MIT license
" (C) 2015, Alisue, hashnote.net
"******************************************************************************
let s:save_cpo = &cpo
set cpo&vim

let s:P = gita#util#import('Prelude')
let s:C = gita#util#import('VCS.Git.Conflict')

function! s:get_gita(...) abort " {{{
  let gita = call('gita#get', a:000)
  let gita.interface = get(gita, 'interface', {})
  let gita.interface.diff = get(gita.interface, 'diff', {})
  return gita
endfunction " }}}
function! s:get_is_bufhidden(expr) abort " {{{
  let bufhidden = getbufvar(a:expr, '&bufhidden')
  return bufhidden == 'hidden' || (bufhidden == '' && &hidden)
endfunction " }}}
function! s:smart_redraw() abort " {{{
  if &diff
    diffupdate | redraw!
  else
    redraw!
  endif
endfunction " }}}

function! s:open2(status, ...) abort " {{{
  let status  = a:status
  let path    = get(status, 'path2', status.path)
  let gita    = s:get_gita(path)
  let options = extend({
        \ 'opener': 'tabedit',
        \ 'vertical': 1,
        \}, get(a:000, 0, {}))
  if !gita.enabled
    redraw | call gita#util#info(
          \ printf(
          \   'Git is not available in the current buffer "%s".',
          \   bufname('%')
          \))
    return
  endif

  " Get a content of ORIG, LOCAL, REMOTE
  let ORIG = bufexists(path) ? getbufline(path, 1, '$') : readfile(path)
  let LOCAL  = a:status.sign =~# '\v%(DD|DU)' ? [] : s:C.strip_theirs(ORIG)
  let REMOTE = a:status.sign =~# '\v%(DD|UD)' ? [] : s:C.get_theirs(a:status.path)

  " Create a buffer names of LOCAL, REMOTE
  let LOCAL_bufname = printf("%s.LOCAL.%s",
        \ fnamemodify(path, ':r'),
        \ fnamemodify(path, ':e'),
        \)
  let REMOTE_bufname = printf("%s.REMOTE.%s",
        \ fnamemodify(path, ':r'),
        \ fnamemodify(path, ':e'),
        \)

  " LOCAL
  silent call gita#util#interface_open(LOCAL_bufname, 'conflict_2way_LOCAL', {
        \ 'opener': options.opener,
        \ 'range': 'all',
        \})
  let LOCAL_bufnum = bufnr('%')
  setlocal buftype=acwrite bufhidden=wipe noswapfile
  nnoremap <buffer><silent> <C-l> :<C-u>call <SID>smart_redraw()<CR>
  augroup vim-gita-conflict
    autocmd! * <buffer>
    autocmd BufWriteCmd <buffer> call s:ac_write_cmd()
    autocmd QuitPre     <buffer> call s:ac_quit_pre()
  augroup END
  call gita#util#buffer_update(LOCAL)

  " REMOTE
  silent call gita#util#interface_open(REMOTE_bufname, 'conflict_2way_REMOTE', {
        \ 'opener': printf('%s botright split', options.vertical ? 'vert' : ''),
        \ 'range': 'all',
        \})
  let REMOTE_bufnum = bufnr('%')
  setlocal buftype=acwrite bufhidden=wipe noswapfile
  nnoremap <buffer><silent> <C-l> :<C-u>call <SID>smart_redraw()<CR>
  augroup vim-gita-conflict
    autocmd! * <buffer>
    autocmd BufWriteCmd <buffer> call s:ac_write_cmd()
    autocmd QuitPre     <buffer> call s:ac_quit_pre()
  augroup END
  setlocal modifiable
  call gita#util#buffer_update(REMOTE)
  setlocal nomodifiable
  diffthis

  call setbufvar(LOCAL_bufnum, '_ORIG_path', path)
  call setbufvar(LOCAL_bufnum, '_REMOTE_bufnum', REMOTE_bufnum)
  call setbufvar(LOCAL_bufnum, '_EDITABLE_bufnum', LOCAL_bufnum)
  call setbufvar(REMOTE_bufnum, '_path', path)
  call setbufvar(REMOTE_bufnum, '_LOCAL_bufnum', LOCAL_bufnum)
  call setbufvar(REMOTE_bufnum, '_EDITABLE_bufnum', LOCAL_bufnum)

  execute bufwinnr(LOCAL_bufnum) 'wincmd w'
  diffthis
  diffupdate
endfunction " }}}
function! s:open3(status, ...) abort " {{{
  let status  = a:status
  let path    = get(status, 'path2', status.path)
  let gita    = s:get_gita(path)
  let options = extend({
        \ 'opener': 'tabedit',
        \ 'vertical': 1,
        \}, get(a:000, 0, {}))
  if !gita.enabled
    redraw | call gita#util#info(
          \ printf(
          \   'Git is not available in the current buffer "%s".',
          \   bufname('%')
          \))
    return
  endif

  " Get a content of ORIG, MERGE, LOCAL, REMOTE
  let ORIG = bufexists(path) ? getbufline(path, 1, '$') : readfile(path)
  let MERGE  = s:C.strip_conflict(ORIG)
  let LOCAL  = a:status.sign =~# '\v%(DD|DU)' ? [] : s:C.get_ours(a:status.path)
  let REMOTE = a:status.sign =~# '\v%(DD|UD)' ? [] : s:C.get_theirs(a:status.path)

  " Create a buffer names of MERGE, LOCAL, REMOTE
  let MERGE_bufname = printf("%s.MERGE.%s",
        \ fnamemodify(path, ':r'),
        \ fnamemodify(path, ':e'),
        \)
  let LOCAL_bufname = printf("%s.LOCAL.%s",
        \ fnamemodify(path, ':r'),
        \ fnamemodify(path, ':e'),
        \)
  let REMOTE_bufname = printf("%s.REMOTE.%s",
        \ fnamemodify(path, ':r'),
        \ fnamemodify(path, ':e'),
        \)

  " MERGE
  silent call gita#util#interface_open(MERGE_bufname, 'conflict_3way_MERGE', {
        \ 'opener': options.opener,
        \ 'range': 'all',
        \})
  let MERGE_bufnum = bufnr('%')
  setlocal buftype=acwrite bufhidden=wipe noswapfile
  nnoremap <buffer><silent> <C-l> :<C-u>call <SID>smart_redraw()<CR>
  execute printf('nnoremap <buffer><silent> dol :<C-u>diffget %s<CR>', LOCAL_bufname)
  execute printf('nnoremap <buffer><silent> dor :<C-u>diffget %s<CR>', REMOTE_bufname)
  augroup vim-gita-conflict
    autocmd! * <buffer>
    autocmd BufWriteCmd <buffer> call s:ac_write_cmd()
    autocmd QuitPre     <buffer> call s:ac_quit_pre()
  augroup END
  call gita#util#buffer_update(MERGE)

  " LOCAL
  silent call gita#util#interface_open(LOCAL_bufname, 'conflict_3way_LOCAL', {
        \ 'opener': printf('%s topleft split', options.vertical ? 'vert' : ''),
        \ 'range': 'all',
        \})
  let LOCAL_bufnum = bufnr('%')
  setlocal buftype=acwrite bufhidden=wipe noswapfile
  nnoremap <buffer><silent> <C-l> :<C-u>call <SID>smart_redraw()<CR>
  execute printf('nnoremap <buffer><silent> dp :<C-u>diffput %s<CR>', MERGE_bufname)
  augroup vim-gita-conflict
    autocmd! * <buffer>
    autocmd BufWriteCmd <buffer> call s:ac_write_cmd()
    autocmd QuitPre     <buffer> call s:ac_quit_pre()
  augroup END
  setlocal modifiable
  call gita#util#buffer_update(LOCAL)
  setlocal nomodifiable
  diffthis

  " REMOTE
  silent call gita#util#interface_open(REMOTE_bufname, 'conflict_3way_REMOTE', {
        \ 'opener': printf('%s botright split', options.vertical ? 'vert' : ''),
        \ 'range': 'all',
        \})
  let REMOTE_bufnum = bufnr('%')
  setlocal buftype=acwrite bufhidden=wipe noswapfile
  nnoremap <buffer><silent> <C-l> :<C-u>call <SID>smart_redraw()<CR>
  execute printf('nnoremap <buffer><silent> dp :<C-u>diffput %s<CR>', MERGE_bufname)
  augroup vim-gita-conflict
    autocmd! * <buffer>
    autocmd BufWriteCmd <buffer> call s:ac_write_cmd()
    autocmd QuitPre     <buffer> call s:ac_quit_pre()
  augroup END
  setlocal modifiable
  call gita#util#buffer_update(REMOTE)
  setlocal nomodifiable
  diffthis

  call setbufvar(MERGE_bufnum, '_ORIG_path', path)
  call setbufvar(MERGE_bufnum, '_LOCAL_bufnum', LOCAL_bufnum)
  call setbufvar(MERGE_bufnum, '_REMOTE_bufnum', REMOTE_bufnum)
  call setbufvar(MERGE_bufnum, '_EDITABLE_bufnum', MERGE_bufnum)
  call setbufvar(LOCAL_bufnum, '_MERGE_bufnum', MERGE_bufnum)
  call setbufvar(LOCAL_bufnum, '_REMOTE_bufnum', REMOTE_bufnum)
  call setbufvar(LOCAL_bufnum, '_EDITABLE_bufnum', MERGE_bufnum)
  call setbufvar(REMOTE_bufnum, '_MERGE_bufnum', MERGE_bufnum)
  call setbufvar(REMOTE_bufnum, '_LOCAL_bufnum', LOCAL_bufnum)
  call setbufvar(REMOTE_bufnum, '_EDITABLE_bufnum', MERGE_bufnum)

  wincmd =
  execute bufwinnr(MERGE_bufnum) 'wincmd w'
  diffthis
  diffupdate
endfunction " }}}
function! s:ac_write_cmd() abort " {{{
  let new_filename = fnamemodify(expand('<amatch>'), ':p')
  let old_filename = fnamemodify(expand('<afile>'), ':p')
  if new_filename !=# old_filename
    execute printf('w%s %s %s',
          \ v:cmdbang ? '!' : '',
          \ fnameescape(v:cmdarg),
          \ fnameescape(new_filename),
          \)
  endif
  if bufnr('%') == b:_EDITABLE_bufnum
    let filename = fnamemodify(expand(b:_ORIG_path), ':p')
    if writefile(getline(1, '$'), filename) == 0
      setlocal nomodified
    endif
  endif
endfunction " }}}
function! s:ac_quit_pre() abort " {{{
  " Synchronize &modified to prevent closing when the editable buffer (LOCAL
  " in 2-way, MERGE in 3-way) is modified
  let &modified = getbufvar(b:_EDITABLE_bufnum, '&modified', 0)
  " Close related buffers only when no modification are applied to the
  " editable buffer or closed with cmdbang
  " Note: v:cmdbang is only for read/write file.
  if !&modified || histget('cmd') =~# '\v!$'
    diffoff
    augroup vim-gita-conflict
      autocmd! * <buffer>
    augroup END
    let bufnums = [
          \ get(b:, '_MERGE_bufnum', -1),
          \ get(b:, '_LOCAL_bufnum', -1),
          \ get(b:, '_REMOTE_bufnum', -1),
          \]
    for bufnum in bufnums
      if bufexists(bufnum)
        execute printf('noautocmd %dwincmd w', bufwinnr(bufnum))
        diffoff
        augroup vim-gita-conflict
          autocmd! * <buffer>
        augroup END
        silent noautocmd quit!
      endif
    endfor
  endif
endfunction " }}}

function! gita#interface#conflict#open2(status, ...) abort " {{{
  let status = s:P.is_dict(a:status) ? a:status : { 'path': a:status }
  call call('s:open2', extend([status], a:000))
endfunction " }}}
function! gita#interface#conflict#open3(status, ...) abort " {{{
  let status = s:P.is_dict(a:status) ? a:status : { 'path': a:status }
  call call('s:open3', extend([status], a:000))
endfunction " }}}
function! gita#interface#conflict#smart_redraw() abort " {{{
  call call('s:smart_redraw')
endfunction " }}}

" Configure " {{{
let s:default = {}
let s:default.define_smart_redraw = 1

function! s:config() abort
  for [key, value] in items(s:default)
    let g:gita#interface#diff#{key} = get(g:, 'gita#interface#diff#' . key, value)
  endfor
endfunction
call s:config()
" }}}

let &cpo = s:save_cpo
unlet! s:save_cpo
"vim: stts=2 sw=2 smarttab et ai textwidth=0 fdm=marker
