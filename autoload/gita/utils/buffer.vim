let s:save_cpoptions = &cpoptions
set cpoptions&vim

let s:D = gita#import('Data.Dict')
let s:B = gita#import('Vim.Buffer')
let s:BM = gita#import('Vim.BufferManager')

function! gita#utils#buffer#bufname(...) abort " {{{
  let bits = filter(deepcopy(a:000), '!empty(v:val)')
  return join(bits, g:gita#utils#buffer#separator)
endfunction " }}}
function! gita#utils#buffer#is_listed_in_tabpage(expr) abort " {{{
  let bufnum = bufnr(a:expr)
  if bufnum == -1
    return 0
  endif
  let buflist = tabpagebuflist()
  return string(bufnum) =~# printf('\v^%%(%s)$', join(buflist, '|'))
endfunction " }}}
function! gita#utils#buffer#update(buflines) abort " {{{
  let saved_cursor = gita#compat#getcurpos()
  let saved_modifiable = &l:modifiable
  let saved_readonly = &l:readonly
  let saved_undolevels = &l:undolevels
  let &l:modifiable=1
  let &l:undolevels=-1
  let &l:readonly=0
  keepjump silent %delete _
  keepjump call setline(1, a:buflines)
  keepjump call setpos('.', saved_cursor)
  let &l:modifiable = saved_modifiable
  let &l:readonly = saved_readonly
  let &l:undolevels = saved_undolevels
  setlocal nomodified
endfunction " }}}
function! gita#utils#buffer#clear_undo_history() abort " {{{
  let saved_undolevels = &undolevels
  let &undolevels = -1
  keepjump silent execute "normal a \<BS>\<ESC>"
  let &undolevels = saved_undolevels
endfunction " }}}
function! gita#utils#buffer#open(name, ...) abort " {{{
  let config = get(a:000, 0, {})
  let group  = get(config, 'group', '')
  if empty(group)
    let loaded = s:B.open(a:name, get(config, 'opener', 'edit'))
    let bufnum = bufnr('%')
    return {
          \ 'loaded': loaded,
          \ 'bufnum': bufnum,
          \}
  else
    let vname = printf('_buffer_manager_%s', group)
    if !has_key(s:, vname)
      let s:{vname} = s:BM.new()
    endif
    let ret = s:{vname}.open(a:name, s:D.pick(config, [
          \ 'opener',
          \ 'range',
          \]))
    return {
          \ 'loaded': ret.loaded,
          \ 'bufnum': ret.bufnr,
          \}
  endif
endfunction " }}}
function! gita#utils#buffer#focus_group(group, ...) abort " {{{
  let options = get(a:000, 0, {})
  let vname = printf('_buffer_manager_%s', a:group)
  if !has_key(s:, vname)
    return 0
  endif
  if get(options, 'keepjumps')
    let near = s:{vname}.nearest()
    if empty(near)
      return 0
    endif
    silent execute printf('keepjumps tabnext %d', near[0])
    silent execute printf('keepjumps %d wincmd w', near[1])
    return 1
  else
    return s:{vname}.move()
  endif
endfunction " }}}

let &cpoptions = s:save_cpoptions
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
