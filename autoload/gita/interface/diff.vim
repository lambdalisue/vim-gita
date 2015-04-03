"******************************************************************************
" vim-gita interface/diff
"
" Author:   Alisue <lambdalisue@hashnote.net>
" URL:      http://hashnote.net/
" License:  MIT license
" (C) 2015, Alisue, hashnote.net
"******************************************************************************
let s:save_cpo = &cpo
set cpo&vim

let s:P = gita#util#import('Prelude')

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

function! s:open(status, commit, ...) abort " {{{
  let path    = get(a:status, 'path2', a:status.path)
  let gita    = s:get_gita(path)
  let options = extend({
        \ 'opener': 'edit',
        \ 'no_prefix': 1,
        \ 'no_color': 1,
        \ 'unified': '0',
        \ 'R': 1,
        \ 'histogram': 1,
        \}, get(a:000, 0, {}))

  if !gita.enabled
    redraw | call gita#util#info(
          \ printf(
          \   'Git is not available in the current buffer "%s".',
          \   bufname('%')
          \))
    return
  endif

  let result = gita.git.diff(options, a:commit, path)
  if result.status != 0
    call gita#util#error(
          \ result.stdout,
          \ printf('Fail: %s', join(result.args)),
          \)
    return
  endif
  let DIFF = split(result.stdout, '\v\r?\n')
  let DIFF_bufname = printf("%s.%s.diff",
        \ path,
        \ empty(a:commit) ? 'INDEX' : a:commit,
        \)
  silent call gita#util#buffer_open(DIFF_bufname, options.opener)
  setlocal buftype=nofile bufhidden=wipe noswapfile nobuflisted

  setlocal modifiable
  call gita#util#buffer_update(DIFF)
  setlocal nomodifiable
endfunction " }}}
function! s:compare(status, commit, ...) abort " {{{
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


  let args = ['show', printf('%s:%s', a:commit, a:status.path)]
  let result = gita.git.exec(args)
  if result.status != 0
    call gita#util#error(
          \ result.stdout,
          \ printf('Fail: %s', join(result.args)),
          \)
    return
  endif
  let REMOTE = split(result.stdout, '\v\r?\n')
  let REMOTE_bufname = printf("%s.%s.REMOTE.%s",
        \ fnamemodify(path, ':r'),
        \ empty(a:commit) ? 'INDEX' : a:commit,
        \ fnamemodify(path, ':e'),
        \)

  " LOCAL
  call gita#util#interface_open(path, 'diff_LOCAL', {
        \ 'opener': options.opener,
        \ 'range': 'all',
        \})
  let LOCAL_bufnum = bufnr('%')
  if g:gita#interface#diff#define_smart_redraw
    nnoremap <buffer><silent> <C-l> :<C-u>call <SID>smart_redraw()<CR>
  endif
  augroup vim-gita-diff
    autocmd! * <buffer>
    autocmd QuitPre     <buffer> call s:ac_quit_pre()
  augroup END

  " REMOTE
  let opener = options.vertical ? 'vert new' : 'new'
  call gita#util#interface_open(REMOTE_bufname, 'diff_REMOTE', {
        \ 'opener': opener,
        \ 'range': 'all',
        \})
  let REMOTE_bufnum = bufnr('%')
  setlocal buftype=acwrite bufhidden=wipe noswapfile
  nnoremap <buffer><silent> <C-l> :<C-u>call <SID>smart_redraw()<CR>
  augroup vim-gita-diff
    autocmd! * <buffer>
    autocmd BufWriteCmd <buffer> call s:ac_write_cmd()
    autocmd QuitPre     <buffer> call s:ac_quit_pre()
  augroup END
  setlocal modifiable
  call gita#util#buffer_update(REMOTE)
  setlocal nomodifiable
  diffthis

  call setbufvar(LOCAL_bufnum, '_REMOTE_bufnum', REMOTE_bufnum)
  call setbufvar(LOCAL_bufnum, '_EDITABLE_bufnum', LOCAL_bufnum)
  call setbufvar(REMOTE_bufnum, '_LOCAL_bufnum', LOCAL_bufnum)
  call setbufvar(REMOTE_bufnum, '_EDITABLE_bufnum', LOCAL_bufnum)

  execute bufwinnr(LOCAL_bufnum) 'wincmd w'
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
endfunction " }}}
function! s:ac_quit_pre() abort " {{{
  " Synchronize &modified to prevent closing when the editable buffer (LOCAL
  " in 2-way, MERGE in 3-way) is modified
  let is_hidden = s:get_is_bufhidden(b:_EDITABLE_bufnum)
  let &modified = getbufvar(b:_EDITABLE_bufnum, '&modified', 0)
  " Close related buffers only when no modification are applied to the
  " editable buffer or closed with cmdbang
  " Note: v:cmdbang is only for read/write file.
  if is_hidden || !&modified || histget('cmd') =~# '\v!$'
    diffoff
    augroup vim-gita-diff
      autocmd! * <buffer>
    augroup END
    let bufnums = [
          \ get(b:, '_LOCAL_bufnum', -1),
          \ get(b:, '_REMOTE_bufnum', -1),
          \]
    for bufnum in bufnums
      if bufexists(bufnum)
        execute printf('noautocmd %dwincmd w', bufwinnr(bufnum))
        diffoff
        augroup vim-gita-diff
          autocmd! * <buffer>
        augroup END
        silent noautocmd quit!
      endif
    endfor
  endif
endfunction " }}}

function! gita#interface#diff#open(status, commit, ...) abort " {{{
  let status = s:P.is_dict(a:status) ? a:status : { 'path': a:status }
  call call('s:open', extend([status, a:commit], a:000))
endfunction " }}}
function! gita#interface#diff#compare(status, commit, ...) abort " {{{
  let status = s:P.is_dict(a:status) ? a:status : { 'path': a:status }
  call call('s:compare', extend([status, a:commit], a:000))
endfunction " }}}
function! gita#interface#diff#smart_redraw() abort " {{{
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
"
"
"
"
