let s:save_cpo = &cpo
set cpo&vim



" Modules
let s:P = gita#utils#import('Prelude')
let s:L = gita#utils#import('Data.List')
let s:C = gita#utils#import('VCS.Git.Conflict')


" Private
function! s:get_gita(...) abort " {{{
  return call('gita#core#get', a:000)
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
          \ 'gita#features#conflict#s:open2',
          \ printf('bufname: "%s"', bufname('%')),
          \ printf('cwd: "%s"', getcwd()),
          \ printf('gita: "%s"', string(gita)),
          \)
    return
  elseif !a:status.is_conflicted && !get(g:, 'gita#debug', 0)
    redraw
    call gita#utils#warn(
          \ 'The file is not conflicted. The operation is going to be canceled.',
          \)
    return
  endif

  let abspath = gita.git.get_absolute_path(path)
  let relpath = gita.git.get_relative_path(path)
  let ORIG = bufexists(relpath) ? getbufline(relpath, 1, '$') : readfile(abspath)
  let LOCAL  = a:status.sign =~# '\v%(DD|DU)' ? [] : s:C.strip_theirs(ORIG)
  let REMOTE = a:status.sign =~# '\v%(DD|UD)' ? [] : s:C.get_theirs(relpath)
  if s:P.is_dict(REMOTE)
    unlet REMOTE
    let REMOTE = ['unavailable']
  endif

  " Create a buffer names of LOCAL, REMOTE
  let LOCAL_bufname = abspath
  let REMOTE_bufname = gita#utils#buffer#bufname(
        \ abspath,
        \ 'REMOTE',
        \)

  let bufnums = gita#utils#buffer#diff2(
        \ LOCAL_bufname, REMOTE_bufname, 'conflict_diff2', {
        \   'opener': get(options, 'opener', 'edit'),
        \   'vertical': get(options, 'vertical', 0),
        \})
  let LOCAL_bufnum = bufnums.bufnum1
  let REMOTE_bufnum = bufnums.bufnum2

  " REMOTE
  execute printf('%swincmd w', bufwinnr(REMOTE_bufnum))
  call gita#utils#buffer#update(REMOTE)
  setlocal buftype=nofile bufhidden=wipe noswapfile
  setlocal nomodifiable

  " LOCAL
  execute printf('%swincmd w', bufwinnr(LOCAL_bufnum))
  diffupdate
endfunction " }}}
function! s:open3(status, ...) abort " {{{
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
          \ printf('gita: "%s"', string(gita)),
          \)
    return
  elseif !a:status.is_conflicted && !get(g:, 'gita#debug', 0)
    redraw
    call gita#utils#warn(
          \ 'The file is not conflicted. The operation is going to be canceled.',
          \)
    return
  endif

  let abspath = gita.git.get_absolute_path(path)
  let relpath = gita.git.get_relative_path(path)
  let ORIG = bufexists(relpath) ? getbufline(relpath, 1, '$') : readfile(abspath)
  let MERGE  = s:C.strip_conflict(ORIG)
  let LOCAL  = a:status.sign =~# '\v%(DD|DU)' ? [] : s:C.get_ours(relpath)
  let REMOTE = a:status.sign =~# '\v%(DD|UD)' ? [] : s:C.get_theirs(relpath)
  if s:P.is_dict(LOCAL)
    let stdout = LOCAL.stdout
    unlet LOCAL
    let LOCAL = stdout
  endif
  if s:P.is_dict(REMOTE)
    let stdout = REMOTE.stdout
    unlet REMOTE
    let REMOTE = stdout
  endif


  " Create a buffer names of LOCAL, REMOTE
  let MERGE_bufname = gita#utils#buffer#bufname(
        \ abspath,
        \ 'MERGE',
        \)
  let LOCAL_bufname = gita#utils#buffer#bufname(
        \ abspath,
        \ 'LOCAL',
        \)
  let REMOTE_bufname = gita#utils#buffer#bufname(
        \ abspath,
        \ 'REMOTE',
        \)

  let bufnums = gita#utils#buffer#diff3(
        \ MERGE_bufname, LOCAL_bufname, REMOTE_bufname, 'conflict_diff3', {
        \   'opener': get(options, 'opener', 'tabedit'),
        \   'vertical': get(options, 'vertical', 0),
        \   'range': get(options, 'range', 'all'),
        \})
  let MERGE_bufnum = bufnums.bufnum1
  let LOCAL_bufnum = bufnums.bufnum2
  let REMOTE_bufnum = bufnums.bufnum3

  " LOCAL
  execute printf('%swincmd w', bufwinnr(LOCAL_bufnum))
  call gita#utils#buffer#update(LOCAL)
  setlocal buftype=acwrite bufhidden=wipe noswapfile
  setlocal nomodifiable
  augroup vim-gita-conflict
    autocmd! * <buffer>
    autocmd BufWriteCmd <buffer> call s:ac_write_cmd()
    autocmd QuitPre     <buffer> call s:ac_quit_pre()
  augroup END

  " REMOTE
  execute printf('%swincmd w', bufwinnr(REMOTE_bufnum))
  call gita#utils#buffer#update(REMOTE)
  setlocal buftype=acwrite bufhidden=wipe noswapfile
  setlocal nomodifiable
  augroup vim-gita-conflict
    autocmd! * <buffer>
    autocmd BufWriteCmd <buffer> call s:ac_write_cmd()
    autocmd QuitPre     <buffer> call s:ac_quit_pre()
  augroup END

  " MERGE
  execute printf('%swincmd w', bufwinnr(MERGE_bufnum))
  call gita#utils#buffer#update(MERGE)
  setlocal buftype=acwrite bufhidden=wipe noswapfile
  augroup vim-gita-conflict
    autocmd! * <buffer>
    autocmd BufWriteCmd <buffer> call s:ac_write_cmd()
    autocmd QuitPre     <buffer> call s:ac_quit_pre()
  augroup END
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
  diffupdate
endfunction " }}}
function! s:ac_write_cmd() abort " {{{
  let new_filename = fnamemodify(gita#utils#expand('<amatch>'), ':p')
  let old_filename = fnamemodify(gita#utils#expand('<afile>'), ':p')
  if new_filename !=# old_filename
    execute printf('w%s %s %s',
          \ v:cmdbang ? '!' : '',
          \ fnameescape(v:cmdarg),
          \ fnameescape(new_filename),
          \)
  endif
  if bufnr('%') == b:_EDITABLE_bufnum
    let filename = fnamemodify(gita#utils#expand(b:_ORIG_path), ':p')
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

function! gita#features#conflict#open2(status, ...) abort " {{{
  let status = gita#utils#ensure_status(a:status)
  call call('s:open2', extend([status], a:000))
endfunction " }}}
function! gita#features#conflict#open3(status, ...) abort " {{{
  let status = gita#utils#ensure_status(a:status)
  call call('s:open3', extend([status], a:000))
endfunction " }}}

let &cpo = s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
