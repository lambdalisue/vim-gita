"******************************************************************************
" vim-gita ui conflict
"
" Author:   Alisue <lambdalisue@hashnote.net>
" URL:      http://hashnote.net/
" License:  MIT license
" (C) 2015, Alisue, hashnote.net
"******************************************************************************
let s:save_cpo = &cpo
set cpo&vim


let s:const = {}
let s:const.markers = {}
let s:const.markers.initial  = repeat('\<', 7)
let s:const.markers.middle   = repeat('\=', 7)
let s:const.markers.terminal = repeat('\>', 7)

function! s:truncate_conflicts(buflines, ...) abort " {{{
  let buflines = gita#util#is_list(a:buflines) ? join(a:buflines, "\n") : a:buflines
  let initial_pattern  = printf('%s[^\n]*', s:const.markers.initial)
  let terminal_pattern = printf('%s[^\n]*', s:const.markers.terminal)
  let conflict_pattern = printf('%s\_.{-}%s', initial_pattern, terminal_pattern)
  let buflines = substitute(buflines, '\v' . conflict_pattern, '', 'g')
  return get(a:000, 0, 0) ? split(buflines, '\v\r?\n') : buflines
endfunction " }}}
function! s:clear_undo_history() abort " {{{
  let undolevels_saved = &undolevels
  setlocal undolevels=-1
  silent execute "normal a \<BS>\<ESC>"
  let &undolevels = undolevels_saved
endfunction " }}}

function! s:has_conflict_markers(...) abort " {{{
  let gita = gita#get()
  if !gita.is_enable
    return
  endif
  let filename = get(a:000, 0, expand('%'))
  let contents = readfile(filename)
  return contents != s:truncate_conflicts(contents, 1)
endfunction " }}}

function! s:solver_open(...) abort " {{{
  let gita = gita#get()
  if !gita.is_enable
    return
  endif
  let filename = get(a:000, 0, expand('%'))

  " LOCAL
  let result = gita.git.exec(['show', printf(':2:%s', filename)])
  if result.status != 0
    call gita#util#error(
          \ result.stdout,
          \ printf('Fail: %s', join(result.args)),
          \)
    return
  endif
  let LOCAL = split(result.stdout, '\v\r?\n')

  " REMOTE
  let result = gita.git.exec(['show', printf(':3:%s', filename)])
  if result.status != 0
    call gita#util#error(
          \ result.stdout,
          \ printf('Fail: %s', join(result.args)),
          \)
    return
  endif
  let REMOTE = split(result.stdout, '\v\r?\n')

  " ORIGINAL
  silent execute 'tabedit ' filename
  let bufname = bufname('%')
  " use buffer content instead of file in case if user modified already
  let MERGED = s:truncate_conflicts(getbufline(bufname, 1, '$'), 1)
  let filetype = &filetype
  " open a new buffer for MERGED and close a buffer for ORIGINAL
  silent execute 'new'
  silent execute 'wincmd p'
  silent execute 'quit'

  " MERGED
  silent execute 'file! ' . bufname . '.MERGED'
  silent execute 'setlocal filetype=' . filetype
  let b:_filename = filename
  let MERGED_bufnum = bufnr('%')
  let saved_cur = getpos('.')
  call setline(1, MERGED)
  call s:clear_undo_history()
  call setpos('.', saved_cur)
  setlocal nomodified
  setlocal buftype=acwrite bufhidden=wipe noswapfile
  silent execute printf('nnoremap <buffer><silent> dol :<C-u>diffget %s.LOCAL<CR>', bufname)
  silent execute printf('nnoremap <buffer><silent> dor :<C-u>diffget %s.REMOTE<CR>', bufname)
  nnoremap <buffer><silent> <C-l> :<C-u>diffupdate<BAR>redraw<CR>
  autocmd! * <buffer>
  autocmd BufWriteCmd <buffer> call s:solver_ac_write()
  autocmd QuitPre <buffer> call s:solver_ac_leave()
  diffthis

  " LOCAL
  silent execute 'topleft vertical new'
  silent execute 'file! ' . bufname . '.LOCAL'
  silent execute 'setlocal filetype=' . filetype
  let LOCAL_bufnum = bufnr('%')
  call setline(1, LOCAL)
  call s:clear_undo_history()
  call setpos('.', [bufnr('%'), 1, 1, 0])
  setlocal nomodified
  setlocal nomodifiable
  setlocal buftype=nofile bufhidden=wipe noswapfile
  silent execute printf('nnoremap <buffer><silent> dp :<C-u>diffput %s<CR>', bufname . '.MERGED')
  nnoremap <buffer><silent> <C-l> :<C-u>diffupdate<BAR>redraw<CR>
  autocmd! * <buffer>
  autocmd QuitPre <buffer> call s:solver_ac_leave()
  diffthis

  " REMOTE
  silent execute 'botright vertical new'
  silent execute 'file! ' . bufname . '.REMOTE'
  silent execute 'setlocal filetype=' . filetype
  let REMOTE_bufnum = bufnr('%')
  call setline(1, REMOTE)
  call s:clear_undo_history()
  call setpos('.', [bufnr('%'), 1, 1, 0])
  setlocal nomodified
  setlocal nomodifiable
  setlocal buftype=nofile bufhidden=wipe noswapfile
  silent execute printf('nnoremap <buffer><silent> dp :<C-u>diffput %s<CR>', bufname . '.MERGED')
  nnoremap <buffer><silent> <C-l> :<C-u>diffupdate<BAR>redraw<CR>
  autocmd! * <buffer>
  autocmd QuitPre <buffer> call s:solver_ac_leave()
  diffthis

  call setbufvar(MERGED_bufnum, '_LOCAL_bufnum', LOCAL_bufnum)
  call setbufvar(MERGED_bufnum, '_REMOTE_bufnum', REMOTE_bufnum)
  call setbufvar(LOCAL_bufnum, '_MERGED_bufnum', MERGED_bufnum)
  call setbufvar(LOCAL_bufnum, '_REMOTE_bufnum', REMOTE_bufnum)
  call setbufvar(REMOTE_bufnum, '_MERGED_bufnum', MERGED_bufnum)
  call setbufvar(REMOTE_bufnum, '_LOCAL_bufnum', LOCAL_bufnum)

  silent execute 'wincmd ='
  silent execute bufwinnr(MERGED_bufnum) 'wincmd w'
endfunction " }}}
function! s:solver_ac_write() abort " {{{
  if writefile(getline(1, '$'), b:_filename) == 0
    setlocal nomodified
  endif
endfunction " }}}
function! s:solver_ac_leave() abort " {{{
  let mybufnum = bufnr('%')
  let bufnums = [
        \ get(b:, '_MERGED_bufnum', -1),
        \ get(b:, '_LOCAL_bufnum', -1),
        \ get(b:, '_REMOTE_bufnum', -1),
        \]
  for bufnum in bufnums
    if bufexists(bufnum) && bufnum != mybufnum && !getbufvar(bufnum, '&modified', 0)
      silent execute printf('noautocmd %dquit', bufwinnr(bufnum))
    endif
  endfor
endfunction " }}}

function! gita#ui#conflict#has_conflict_markers(...) abort " {{{
  return call('s:has_conflict_markers', a:000)
endfunction " }}}
function! gita#ui#conflict#solver_open(...) abort " {{{
  call call('s:solver_open', a:000)
endfunction " }}}

let &cpo = s:save_cpo
unlet! s:save_cpo
"vim: stts=2 sw=2 smarttab et ai textwidth=0 fdm=marker

