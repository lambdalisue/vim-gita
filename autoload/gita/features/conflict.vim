let s:save_cpo = &cpo
set cpo&vim



" Modules
let s:L = gita#utils#import('Data.List')
let s:C = gita#util#import('VCS.Git.Conflict')


" Private
function! s:get_gita(...) abort " {{{
  return call('gita#core#get', a:000)
endfunction " }}}
function! s:smart_redraw() abort " {{{
  call gita#features#diff#smart_redraw()
endfunction " }}}

function! s:open2(status, ...) abort " {{{
  let path = get(a:status, 'path2', a:status.path)
  let gita = s:get_gita(path)
  let options = get(a:000, 0, {})

  if !gita.enabled
    redraw
    call gita#utils#warn(
          \ 'Gita is not available in the current buffer.',
          \)
    call gita#utils#debugmsg(
          \ 'gita#features#diff#s:diff',
          \ printf('bufname: "%s"', bufname('%')),
          \ printf('cwd: "%s"', getcwd()),
          \ printf('gita: "%s"', gita),
          \)
    return
  endif

  let abspath = gita.git.get_absolute_path(path)
  let relpath = gita.git.get_relative_path(path)
  let ORIG = bufexists(relpath) ? getbufline(relpath, 1, '$') : readfile(abspath)
  let LOCAL = a:status.sign =~# '\v%(DD|DU)' ? [] : s:C.strip_theirs(ORIG)
  let REMOTE = a:status.sign =~# '\v%(DD|UD)' ? [] : s:C.get_theirs(relpath)

  " Create a buffer names of LOCAL, REMOTE
  let LOCAL_bufname = gita#utils#buffer#bufname(
        \ abspath,
        \ 'LOCAL',
        \)
  let REMOTE_bufname = gita#utils#buffer#bufname(
        \ abspath,
        \ 'REMOTE',
        \)

  let args = s:L.flatten([
        \ 'show',
        \ printf('%s:%s', a:commit, relpath),
        \])
  let result = gita.exec(args)
  if result.status != 0
    return
  endif

  let REF = split(result.stdout, '\v\r?\n')
  let REF_bufname = gita#utils#buffer#bufname(
        \ path,
        \ empty(a:commit) ? 'INDEX' : a:commit,
        \)
  let opener = get(options, 'opener', 'edit')

  " LOCAL
  call gita#utils#buffer#open(path, 'diff_LOCAL', {
        \ 'opener': opener,
        \})
  let LOCAL_bufnum = bufnr('%')
  nnoremap <buffer><silent> <Plug>(gita-smart-redraw)
        \ :<C-u>call <SID>smart_redraw()<CR>
  nmap <buffer> <C-l> <Plug>(gita-smart-redraw)
  augroup vim-gita-diff
    autocmd! * <buffer>
    autocmd BufWinLeave <buffer> call s:ac_buf_win_leave()
  augroup END
  diffthis

  " REFERENCE
  if gita#utils#buffer#is_listed_in_tabpage(REF_bufname)
    let opener = 'edit'
  else
    let opener = get(options, 'vertical') ? 'vert split' : 'split'
  endif
  call gita#utils#buffer#open(REF_bufname, 'diff_REF', {
        \ 'opener': opener,
        \})
  let REF_bufnum = bufnr('%')
  nnoremap <buffer><silent> <Plug>(gita-smart-redraw)
        \ :<C-u>call <SID>smart_redraw()<CR>
  nmap <buffer> <C-l> <Plug>(gita-smart-redraw)
  augroup vim-gita-diff
    autocmd! * <buffer>
    autocmd BufWinLeave <buffer> call s:ac_buf_win_leave()
  augroup END
  call gita#utils#buffer#update(REF)
  setlocal buftype=nofile bufhidden=wipe noswapfile
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


let &cpo = s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
