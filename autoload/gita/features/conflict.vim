let s:save_cpo = &cpo
set cpo&vim

let s:P = gita#utils#import('Prelude')
let s:C = gita#utils#import('VCS.Git.Conflict')
let s:A = gita#utils#import('ArgumentParser')


let s:parser = s:A.new({
      \ 'name': 'Gita[!] conflict',
      \ 'description': 'Solve a conflicted file in merge mode.',
      \})
call s:parser.add_argument(
      \ 'file', [
      \   'A file to solve conflict.',
      \ ], {
      \   'complete': function('gita#utils#completes#complete_conflicted_files'),
      \})
call s:parser.add_argument(
      \ '--window', '-w',
      \ 'Open double/triple window to solve the conflict (Default: triple)', {
      \   'choices': ['double', 'triple'],
      \   'default': 'triple',
      \ })

function! s:ensure_status_option(options) abort " {{{
  if !has_key(a:options, 'status') && !has_key(a:options, 'file')
    call gita#utils#prompt#error(
          \ '"status" nor "file" is specified.',
          \)
    return -1
  elseif has_key(a:options, 'status')
    let a:options.file = get(a:options.status, 'path2', a:options.status.path)
  else
    let a:options.status = gita#utils#get_status(a:options.file)
  endif
  let a:options.file = gita#utils#expand(a:options.file)
  return 0
endfunction " }}}
function! s:ac_BufWriteCmd() abort " {{{
  let new_filename = fnamemodify(expand('<amatch>'), ':p')
  let old_filename = fnamemodify(expand('<afile>'), ':p')
  if new_filename !=# old_filename
    execute printf('w%s %s %s',
          \ v:cmdbang ? '!' : '',
          \ fnameescape(v:cmdarg),
          \ fnameescape(new_filename),
          \)
  else
    let filename = fnamemodify(expand(b:_gita_original_filename), ':p')
    if writefile(getline(1, '$'), filename) == 0
      setlocal nomodified
    endif
  endif
endfunction " }}}
function! s:solve2(...) abort " {{{
  let gita = gita#get()
  let options = get(a:000, 0, {})
  let abspath = gita.git.get_absolute_path(options.file)
  let relpath = gita.git.get_relative_path(abspath)

  let ORIG = bufexists(abspath)
        \ ? getbufline(abspath, 1, '$')
        \ : readfile(abspath)
  let MERGE = options.status.sign =~# '\%(DD\|DU\)'
        \ ? []
        \ : s:C.strip_theirs(ORIG)
  let REMOTE = options.status.sign =~# '\%(DD\|UD\)'
        \ ? []
        \ : s:C.get_theirs(relpath)
  if s:P.is_dict(REMOTE)
    let stdout = REMOTE.stdout
    unlet REMOTE
    let REMOTE = stdout
  endif

  let MERGE_bufname = gita#utils#buffer#bufname(
        \ 'MERGE',
        \ relpath,
        \)
  let REMOTE_bufname = gita#utils#buffer#bufname(
        \ 'REMOTE',
        \ relpath,
        \)
  let bufnums = gita#utils#buffer#open2(
        \ MERGE_bufname, REMOTE_bufname, 'conflict_diff2', {
        \   'opener': get(options, 'opener', 'edit'),
        \   'vertical': get(options, 'vertical', 0),
        \})
  let MERGE_bufnum = bufnums.bufnum1
  let REMOTE_bufnum = bufnums.bufnum2

  " REMOTE
  execute printf('%swincmd w', bufwinnr(REMOTE_bufnum))
  call gita#utils#buffer#update(REMOTE)
  let b:_gita_original_filename = abspath
  setlocal buftype=nofile bufhidden=hide noswapfile
  setlocal nomodifiable readonly
  diffthis

  " MERGE
  execute printf('%swincmd w', bufwinnr(MERGE_bufnum))
  call gita#utils#buffer#update(MERGE)
  let b:_gita_original_filename = abspath
  setlocal buftype=acwrite bufhidden=hide noswapfile
  augroup vim-gita-conflict-solve2
    autocmd! * <buffer>
    autocmd BufWriteCmd <buffer> call s:ac_BufWriteCmd()
  augroup END
  diffthis
  diffupdate
endfunction " }}}
function! s:solve3(...) abort " {{{
  let gita = gita#get()
  let options = get(a:000, 0, {})
  let abspath = gita.git.get_absolute_path(options.file)
  let relpath = gita.git.get_relative_path(abspath)

  let ORIG = bufexists(abspath)
        \ ? getbufline(abspath, 1, '$')
        \ : readfile(abspath)
  let MERGE  = s:C.strip_conflict(ORIG)
  let LOCAL  = options.status.sign =~# '\v%(DD|DU)'
        \ ? []
        \ : s:C.get_ours(relpath)
  let REMOTE = options.status.sign =~# '\v%(DD|UD)'
        \ ? []
        \ : s:C.get_theirs(relpath)
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
        \ 'MERGE',
        \ relpath,
        \)
  let LOCAL_bufname = gita#utils#buffer#bufname(
        \ 'LOCAL',
        \ relpath,
        \)
  let REMOTE_bufname = gita#utils#buffer#bufname(
        \ 'REMOTE',
        \ relpath,
        \)

  let bufnums = gita#utils#buffer#open3(
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
  let b:_gita_original_filename = abspath
  setlocal buftype=nofile bufhidden=hide noswapfile
  setlocal nomodifiable readonly
  execute printf(join([
        \   'noremap <buffer><silent> <Plug>(gita-action-diffput)',
        \   ':<C-u>diffput %s<BAR>diffupdate<CR>',
        \ ]),
        \ MERGE_bufnum,
        \)
  nmap <buffer> dp <Plug>(gita-action-diffput)
  diffthis

  " REMOTE
  execute printf('%swincmd w', bufwinnr(REMOTE_bufnum))
  call gita#utils#buffer#update(REMOTE)
  let b:_gita_original_filename = abspath
  setlocal buftype=nofile bufhidden=hide noswapfile
  setlocal nomodifiable readonly
  execute printf(join([
        \   'noremap <buffer><silent> <Plug>(gita-action-diffput)',
        \   ':<C-u>diffput %s<BAR>diffupdate<CR>',
        \ ]),
        \ MERGE_bufnum,
        \)
  nmap <buffer> dp <Plug>(gita-action-diffput)
  diffthis

  " MERGE
  execute printf('%swincmd w', bufwinnr(MERGE_bufnum))
  call gita#utils#buffer#update(MERGE)
  let b:_gita_original_filename = abspath
  let b:_gita_LOCAL_bufnum = LOCAL_bufnum
  let b:_gita_REMOTE_bufnum = REMOTE_bufnum
  setlocal buftype=acwrite bufhidden=hide noswapfile
  execute printf(join([
        \   'noremap <buffer><silent> <Plug>(gita-action-diffget-LOCAL)',
        \   ':<C-u>diffget %s<BAR>diffupdate<CR>',
        \ ]),
        \ LOCAL_bufnum,
        \)
  execute printf(join([
        \   'noremap <buffer><silent> <Plug>(gita-action-diffget-REMOTE)',
        \   ':<C-u>diffget %s<BAR>diffupdate<CR>',
        \ ]),
        \ REMOTE_bufnum,
        \)
  nmap <buffer> dol <Plug>(gita-action-diffget-LOCAL)
  nmap <buffer> dor <Plug>(gita-action-diffget-REMOTE)
  augroup vim-gita-conflict-solve3
    autocmd! * <buffer>
    autocmd BufWriteCmd <buffer> call s:ac_BufWriteCmd()
  augroup END
  diffthis

  wincmd =
  diffupdate
endfunction " }}}

function! gita#features#conflict#show(...) abort " {{{
  let gita = gita#get()
  if gita.fail_on_disabled()
    return
  endif
  let options = get(a:000, 0, {})
  if s:ensure_status_option(options)
    return
  endif

  if options.window == 'double'
    call s:solve2(options)
  else
    call s:solve3(options)
  endif
endfunction " }}}
function! gita#features#conflict#command(bang, range, ...) abort " {{{
  let options = s:parser.parse(a:bang, a:range, get(a:000, 0, ''))
  if !empty(options)
    let options = extend(
          \ deepcopy(g:gita#features#conflict#default_options),
          \ options)
    if empty(get(options, 'file', ''))
      let options.file = '%'
    endif
    call gita#features#conflict#show(options)
  endif
endfunction " }}}
function! gita#features#conflict#complete(arglead, cmdline, cursorpos) abort " {{{
  return s:parser.complete(a:arglead, a:cmdline, a:cursorpos)
endfunction " }}}

let &cpo = s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
