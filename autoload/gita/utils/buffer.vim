let s:save_cpo = &cpo
set cpo&vim

let s:B = gita#utils#import('Vim.Buffer')
let s:BM = gita#utils#import('Vim.BufferManager')


function! gita#utils#buffer#open(name, group, ...) abort " {{{
  let config = get(a:000, 0, {})
  if empty(a:group)
    let opener = get(config, 'opener', 'edit')
    let loaded = s:B.open(a:name, opener)
    let bufnum = bufnr('%')
    return {
          \ 'loaded': loaded,
          \ 'bufnum': bufnum,
          \}
  else
    let vname = printf('_buffer_manager_%s', a:group)
    if !has_key(s:, vname)
      let s:{vname} = s:BM.new(config)
    endif
    let ret = s:{vname}.open(a:name, config)
    return {
          \ 'loaded': ret.loaded,
          \ 'bufnum': ret.bufnr,
          \}
  endif
endfunction " }}}
function! gita#utils#buffer#open2(name1, name2, group, ...) abort " {{{
  let options = extend({
        \ 'opener': 'edit',
        \ 'vertical': 0,
        \ 'range': 'tabpage',
        \}, get(a:000, 0, {}))
  " 1st buffer
  let opener = get(options, 'opener', 'edit')
  let result1 = s:open(a:name1, printf('%s_1', a:group), {
        \ 'opener': opener,
        \ 'range': options.range,
        \})
  " 2nd buffer
  let vertical = get(options, 'vertical', 0)
  if gita#utils#buffer#is_listed_in_tabpage(a:name2)
    let opener = 'edit'
  else
    let opener = vertical ? 'vert split' : 'split'
  endif
  let result2 = s:open(a:name2, printf('%s_2', a:group), {
        \ 'opener': opener,
        \ 'range': options.range,
        \})
  return {
        \ 'bufnum1': result1.bufnum,
        \ 'bufnum2': result2.bufnum,
        \ 'loaded1': result1.loaded,
        \ 'loaded2': result2.loaded,
        \}
endfunction " }}}
function! gita#utils#buffer#open3(name1, name2, name3, group, ...) abort " {{{
  let options = extend({
        \ 'opener': 'tabedit',
        \ 'vertical': 0,
        \ 'range': 'all',
        \}, get(a:000, 0, {}))
  " 1st buffer
  let opener = get(options, 'opener', 'tabedit')
  let result1 = s:open(a:name1, printf('%s_1', a:group), {
        \ 'opener': opener,
        \ 'range': options.range,
        \})
  " 2nd buffer (from 1st)
  let vertical = get(options, 'vertical', 0)
  if gita#utils#buffer#is_listed_in_tabpage(a:name2)
    let opener = 'edit'
  else
    let opener = vertical ? 'vert leftabove split' : 'leftabove split'
  endif
  let result2 = s:open(a:name2, printf('%s_2', a:group), {
        \ 'opener': opener,
        \ 'range': options.range,
        \})
  " 3rd buffer (from 1st)
  silent execute printf('%swincmd w', bufwinnr(result1.bufnr))
  if gita#utils#buffer#is_listed_in_tabpage(a:name3)
    let opener = 'edit'
  else
    let opener = vertical ? 'vert rightbelow split' : 'rightbelow split'
  endif
  let result3 = s:open(a:name3, printf('%s_3', a:group), {
        \ 'opener': opener,
        \ 'range': options.range,
        \})
  return {
        \ 'bufnum1': result1.bufnum,
        \ 'bufnum2': result2.bufnum,
        \ 'bufnum3': result3.bufnum,
        \ 'loaded1': result1.loaded,
        \ 'loaded2': result2.loaded,
        \ 'loaded3': result3.loaded,
        \}
endfunction " }}}
function! gita#utils#buffer#update(buflines) abort " {{{
  let saved_cursor = getpos('.')
  let saved_modifiable = &l:modifiable
  let saved_readonly = &l:readonly
  let saved_undolevels = &l:undolevels
  let &l:modifiable=1
  let &l:undolevels=-1
  let &l:readonly=0
  silent %delete _
  call setline(1, a:buflines)
  call setpos('.', saved_cursor)
  let &l:modifiable = saved_modifiable
  let &l:readonly = saved_readonly
  let &l:undolevels = saved_undolevels
  setlocal nomodified
endfunction " }}}
function! gita#utils#buffer#is_listed_in_tabpage(expr) abort " {{{
  let bufnum = bufnr(a:expr)
  if bufnum == -1
    return 0
  endif
  let buflist = tabpagebuflist()
  return string(bufnum) =~# printf('\v^%%(%s)$', join(buflist, '|'))
endfunction " }}}
function! gita#utils#buffer#bufname(name, ...) abort " {{{
  let sep = has('unix') ? ':' : '-'
  return join(['gita'] + a:000 + [a:name], sep)
endfunction " }}}
function! gita#utils#buffer#clear_undo_history() abort " {{{
  let saved_undolevels = &undolevels
  let &undolevels = -1
  silent execute "normal a \<BS>\<ESC>"
  let &undolevels = saved_undolevels
endfunction " }}}

let &cpo = s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
