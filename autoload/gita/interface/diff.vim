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
        \ 'opener': 'edit',
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
  let REF = split(result.stdout, '\v\r?\n')
  let REF_bufname = gita#util#buffer_get_name(
        \ path,
        \ empty(a:commit) ? 'INDEX' : a:commit,
        \)

  " LOCAL
  silent call gita#util#interface_open(path, 'diff_LOCAL', {
        \ 'opener': options.opener,
        \})
  let LOCAL_bufnum = bufnr('%')
  nnoremap <buffer><silent> <Plug>(gita-smart-redraw) :<C-u>call <SID>smart_redraw()<CR>
  call gita#util#smart_define('<C-l>', '<Plug>(gita-smart-redraw)', 'n', { 'buffer': 1 })
  augroup vim-gita-diff
    autocmd! * <buffer>
    autocmd BufWinLeave <buffer> call s:ac_buf_win_leave()
  augroup END
  diffthis

  " REMOTE
  if gita#util#buffer_is_listed_in_tabpage(REF_bufname)
    let opener = 'edit'
  else
    let opener = options.vertical ? 'vert split' : 'split'
  endif
  silent call gita#util#interface_open(REF_bufname, 'diff_REF', {
        \ 'opener': opener,
        \})
  let REF_bufnum = bufnr('%')
  setlocal buftype=nofile bufhidden=wipe noswapfile
  nnoremap <buffer><silent> <Plug>(gita-smart-redraw) :<C-u>call <SID>smart_redraw()<CR>
  nmap <buffer> <C-l> <Plug>(gita-smart-redraw)
  augroup vim-gita-diff
    autocmd! * <buffer>
    autocmd BufWinLeave <buffer> call s:ac_buf_win_leave()
  augroup END
  setlocal modifiable
  call gita#util#buffer_update(REF)
  setlocal nomodifiable
  diffthis

  diffupdate
endfunction " }}}
function! s:ac_buf_win_leave() abort " {{{
  diffoff
  augroup vim-gita-diff
    autocmd! * <buffer>
  augroup END
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
