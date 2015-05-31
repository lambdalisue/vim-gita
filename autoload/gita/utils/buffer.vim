let s:save_cpo = &cpo
set cpo&vim


" Private functions
function! s:smart_redraw() abort " {{{
  if &diff
    diffupdate | redraw!
  else
    redraw!
  endif
endfunction " }}}
function! s:open(name, group, ...) abort " {{{
  let config = get(a:000, 0, {})
  if empty(a:group)
    let B = gita#utils#import('Vim.Buffer')
    let opener = get(config, 'opener', 'edit')
    let loaded = B.open(a:name, opener)
    let bufnr = bufnr('%')
    return {
          \ 'loaded': loaded,
          \ 'bufnr': bufnr,
          \}
  else
    let vname = printf('_buffer_manager_%s', a:group)
    if !has_key(s:, vname)
      let BM = gita#utils#import('Vim.BufferManager')
      let s:{vname} = BM.new(config)
    endif
    let ret = s:{vname}.open(a:name, config)
    return {
          \ 'loaded': ret.loaded,
          \ 'bufnr': ret.bufnr,
          \}
  endif
endfunction " }}}
function! s:open2(name1, name2, group, ...) abort " {{{
  let options = extend({
        \ 'opener': 'edit',
        \ 'vertical': 0,
        \ 'range': 'tabpage',
        \}, get(a:000, 0, {}))
  " 1st buffer
  let opener = get(options, 'opener', 'edit')
  call s:open(a:name1, printf('%s_1', a:group), {
        \ 'opener': opener,
        \ 'range': options.range,
        \})
  let bufnum1 = bufnr('%')
  " 2nd buffer
  let vertical = get(options, 'vertical', 0)
  if s:is_listed_in_tabpage(a:name2)
    let opener = 'edit'
  else
    let opener = vertical ? 'vert split' : 'split'
  endif
  call s:open(a:name2, printf('%s_2', a:group), {
        \ 'opener': opener,
        \ 'range': options.range,
        \})
  let bufnum2 = bufnr('%')
  return {
        \ 'bufnum1': bufnum1,
        \ 'bufnum2': bufnum2,
        \}
endfunction " }}}
function! s:open3(name1, name2, name3, group, ...) abort " {{{
  let options = extend({
        \ 'opener': 'tabedit',
        \ 'vertical': 0,
        \ 'range': 'all',
        \}, get(a:000, 0, {}))
  " 1st buffer
  let opener = get(options, 'opener', 'tabedit')
  call s:open(a:name1, printf('%s_1', a:group), {
        \ 'opener': opener,
        \ 'range': options.range,
        \})
  let bufnum1 = bufnr('%')
  " 2nd buffer (from 1st)
  let vertical = get(options, 'vertical', 0)
  if s:is_listed_in_tabpage(a:name2)
    let opener = 'edit'
  else
    let opener = vertical ? 'vert topleft split' : 'topleft split'
  endif
  call s:open(a:name2, printf('%s_2', a:group), {
        \ 'opener': opener,
        \ 'range': options.range,
        \})
  let bufnum2 = bufnr('%')
  " 3rd buffer (from 1st)
  silent execute printf('%swincmd w', bufwinnr(bufnum1))
  if s:is_listed_in_tabpage(a:name3)
    let opener = 'edit'
  else
    let opener = vertical ? 'vert botright split' : 'botright split'
  endif
  call s:open(a:name3, printf('%s_3', a:group), {
        \ 'opener': opener,
        \ 'range': options.range,
        \})
  let bufnum3 = bufnr('%')
  return {
        \ 'bufnum1': bufnum1,
        \ 'bufnum2': bufnum2,
        \ 'bufnum3': bufnum3,
        \}
endfunction " }}}
function! s:diff2(...) abort " {{{
  function! s:diff2_ac_buf_win_leave()
    diffoff
    augroup vim-gita-diff2
      autocmd! * <buffer>
    augroup END
  endfunction
  let bufnums = call('s:open2', a:000)

  silent execute printf('%swincmd w', bufwinnr(bufnums.bufnum1))
  nnoremap <buffer><silent> <Plug>(gita-smart-redraw)
        \ :<C-u>call <SID>smart_redraw()<CR>
  nmap <buffer> <C-l> <Plug>(gita-smart-redraw)
  augroup vim-gita-diff2
    autocmd! * <buffer>
    autocmd BufWinLeave <buffer> call s:diff2_ac_buf_win_leave()
  augroup END
  diffthis

  silent execute printf('%swincmd w', bufwinnr(bufnums.bufnum2))
  nnoremap <buffer><silent> <Plug>(gita-smart-redraw)
        \ :<C-u>call <SID>smart_redraw()<CR>
  nmap <buffer> <C-l> <Plug>(gita-smart-redraw)
  augroup vim-gita-diff2
    autocmd! * <buffer>
    autocmd BufWinLeave <buffer> call s:diff2_ac_buf_win_leave()
  augroup END
  diffthis
  return bufnums
endfunction " }}}
function! s:diff3(...) abort " {{{
  function! s:diff3_ac_buf_win_leave()
    diffoff
    augroup vim-gita-diff3
      autocmd! * <buffer>
    augroup END
  endfunction
  let bufnums = call('s:open3', a:000)

  silent execute printf('%swincmd w', bufwinnr(bufnums.bufnum1))
  nnoremap <buffer><silent> <Plug>(gita-smart-redraw)
        \ :<C-u>call <SID>smart_redraw()<CR>
  nmap <buffer> <C-l> <Plug>(gita-smart-redraw)
  augroup vim-gita-diff3
    autocmd! * <buffer>
    autocmd BufWinLeave <buffer> call s:diff2_ac_buf_win_leave()
  augroup END
  diffthis

  silent execute printf('%swincmd w', bufwinnr(bufnums.bufnum2))
  nnoremap <buffer><silent> <Plug>(gita-smart-redraw)
        \ :<C-u>call <SID>smart_redraw()<CR>
  nmap <buffer> <C-l> <Plug>(gita-smart-redraw)
  augroup vim-gita-diff3
    autocmd! * <buffer>
    autocmd BufWinLeave <buffer> call s:diff2_ac_buf_win_leave()
  augroup END
  diffthis

  silent execute printf('%swincmd w', bufwinnr(bufnums.bufnum3))
  nnoremap <buffer><silent> <Plug>(gita-smart-redraw)
        \ :<C-u>call <SID>smart_redraw()<CR>
  nmap <buffer> <C-l> <Plug>(gita-smart-redraw)
  augroup vim-gita-diff3
    autocmd! * <buffer>
    autocmd BufWinLeave <buffer> call s:diff2_ac_buf_win_leave()
  augroup END
  diffthis
  return bufnums
endfunction " }}}
function! s:update(buflines) abort " {{{
  let saved_cursor = getpos('.')
  let saved_modifiable = &l:modifiable
  let saved_undolevels = &l:undolevels
  let &l:modifiable=1
  let &l:undolevels=-1
  silent %delete _
  call setline(1, a:buflines)
  call setpos('.', saved_cursor)
  let &l:modifiable = saved_modifiable
  let &l:undolevels = saved_undolevels
  setlocal nomodified
endfunction " }}}
function! s:clear_undo_history() abort " {{{
  let saved_undolevels = &undolevels
  let &undolevels = -1
  silent execute "normal a \<BS>\<ESC>"
  let &undolevels = saved_undolevels
endfunction " }}}
function! s:is_listed_in_tabpage(expr) abort " {{{
  let bufnum = bufnr(a:expr)
  if bufnum == -1
    return 0
  endif
  let buflist = tabpagebuflist()
  return string(bufnum) =~# printf('\v^%%(%s)$', join(buflist, '|'))
endfunction " }}}
function! s:bufname(name, ...) abort " {{{
  let sep = has('unix') ? ':' : '#'
  return join(['gita'] + a:000 + [a:name], sep)
endfunction " }}}


" Public functions
function! gita#utils#buffer#open(...) abort " {{{
  return call('s:open', a:000)
endfunction " }}}
function! gita#utils#buffer#open2(...) abort " {{{
  return call('s:open2', a:000)
endfunction " }}}
function! gita#utils#buffer#diff2(...) abort " {{{
  return call('s:diff2', a:000)
endfunction " }}}
function! gita#utils#buffer#diff3(...) abort " {{{
  return call('s:diff3', a:000)
endfunction " }}}
function! gita#utils#buffer#update(...) abort " {{{
  return call('s:update', a:000)
endfunction " }}}
function! gita#utils#buffer#clear_undo_history(...) abort " {{{
  return call('s:clear_undo_history', a:000)
endfunction " }}}
function! gita#utils#buffer#is_listed_in_tabpage(...) abort " {{{
  return call('s:is_listed_in_tabpage', a:000)
endfunction " }}}
function! gita#utils#buffer#bufname(...) abort " {{{
  return call('s:bufname', a:000)
endfunction " }}}

let &cpo = s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
