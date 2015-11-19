let s:save_cpoptions = &cpoptions
set cpoptions&vim

let s:P = gita#import('Prelude')
let s:C = gita#import('VCS.Git.Conflict')
let s:A = gita#import('ArgumentParser')


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
      \ '--split', '-s',
      \ 'Specify the number of buffer for showing conflict', {
      \   'choices': ['2', '3'],
      \   'on_default': '3',
      \ })

function! s:ac_BufWriteCmd() abort " {{{
  let new_filename = gita#utils#path#real_abspath(
        \ gita#utils#path#unix_abspath(expand('<amatch>')),
        \)
  let old_filename = gita#utils#path#real_abspath(
        \ gita#utils#path#unix_abspath(expand('%')),
        \)
  if new_filename !=# old_filename
    let cmd = printf('w%s %s',
          \ v:cmdbang ? '!' : '',
          \ fnameescape(new_filename),
          \)
    silent! execute cmd
  else
    let filename = gita#meta#get('filename')
    if writefile(getline(1, '$'), filename) == 0
      setlocal nomodified
    endif
  endif
endfunction " }}}
function! s:ensure_status_option(options) abort " {{{
  if !has_key(a:options, 'status') && !has_key(a:options, 'file')
    call gita#utils#prompt#error(
          \ '"status" nor "file" is specified.',
          \)
    return -1
  elseif has_key(a:options, 'status')
    let a:options.file = get(a:options.status, 'path2', a:options.status.path)
  else
    let a:options.status = gita#utils#status#retrieve(a:options.file)
  endif
  return 0
endfunction " }}}
function! s:solve2(...) abort " {{{
  let options = get(a:000, 0, {})
  let abspath = gita#utils#path#unix_abspath(
        \ gita#utils#path#expand(options.file),
        \)
  let relpath = gita#utils#path#unix_relpath(abspath)

  " Create buffer names of LOCAL, REMOTE
  let LOCAL_bufname = gita#utils#buffer#bufname(
        \ 'LOCAL',
        \ relpath,
        \)
  let REMOTE_bufname = gita#utils#buffer#bufname(
        \ 'REMOTE',
        \ relpath,
        \)

  " Load buffer contents
  let result = gita#features#file#exec_cached({
        \ 'commit': ':2',
        \ 'file': abspath,
        \}, {
        \ 'echo': '',
        \})
  if result.status == 0
    let LOCAL = split(result.stdout, '\v\r?\n')
  else
    let LOCAL = []
  endif
  let result = gita#features#file#exec_cached({
        \ 'commit': ':3',
        \ 'file': abspath,
        \}, {
        \ 'echo': '',
        \})
  if result.status == 0
    let REMOTE = split(result.stdout, '\v\r?\n')
  else
    let REMOTE = []
  endif

  " Open buffers
  " REMOTE
  call gita#utils#buffer#open(REMOTE_bufname, {
        \ 'group': 'conflict2_remote',
        \ 'range': get(options, 'range', 'tabpage'),
        \ 'opener': get(options, 'opener', 'edit'),
        \})
  call gita#utils#buffer#update(REMOTE)
  call gita#meta#set('filename', abspath)
  setlocal buftype=nofile noswapfile
  setlocal nomodifiable readonly
  diffthis

  " LOCAL
  call gita#utils#buffer#open(LOCAL_bufname, {
        \ 'group': 'conflict2_merge',
        \ 'range': get(options, 'range', 'tabpage'),
        \ 'opener': printf('%s%s',
        \   get(options, 'vertical') ? 'vertical ' : '',
        \   get(options, 'opener2', 'split'),
        \ ),
        \})
  call gita#utils#buffer#update(LOCAL)
  call gita#meta#set('filename', abspath)
  setlocal buftype=acwrite noswapfile
  setlocal modified
  augroup vim-gita-conflict-solve2
    autocmd! * <buffer>
    autocmd BufWriteCmd <buffer> call s:ac_BufWriteCmd()
  augroup END
  diffthis
  diffupdate
endfunction " }}}
function! s:solve3(...) abort " {{{
  let options = get(a:000, 0, {})
  let abspath = gita#utils#path#unix_abspath(
        \ gita#utils#path#expand(options.file),
        \)
  let relpath = gita#utils#path#unix_relpath(abspath)

  " Create buffer names of LOCAL, MERGE, REMOTE
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

  " Load buffer contents
  " Note:
  "   s:C.strip_conflict automatically apply non conflicted lines thus
  "   use the feature rather than gita#features#file#exec_cached in MERGE
  if filereadable(abspath)
    let ORIG = bufexists(abspath)
          \ ? getbufline(abspath, 1, '$')
          \ : readfile(abspath)
    let MERGE  = s:C.strip_conflict(ORIG)
  else
    let result = gita#features#file#exec_cached({
          \ 'commit': ':1',
          \ 'file': abspath,
          \}, {
          \ 'echo': '',
          \})
    if result.status == 0
      let MERGE = split(result.stdout, '\v\r?\n')
    else
      let MERGE = []
    endif
  endif
  let result = gita#features#file#exec_cached({
        \ 'commit': ':2',
        \ 'file': abspath,
        \}, {
        \ 'echo': '',
        \})
  if result.status == 0
    let LOCAL = split(result.stdout, '\v\r?\n')
  else
    let LOCAL = []
  endif
  let result = gita#features#file#exec_cached({
        \ 'commit': ':3',
        \ 'file': abspath,
        \}, {
        \ 'echo': '',
        \})
  if result.status == 0
    let REMOTE = split(result.stdout, '\v\r?\n')
  else
    let REMOTE = []
  endif

  " Open buffers
  " MERGE
  call gita#utils#buffer#open(MERGE_bufname, {
        \ 'group': 'conflict3_merge',
        \ 'range': get(options, 'range', 'tabpage'),
        \ 'opener': get(options, 'opener', 'edit'),
        \})
  call gita#utils#buffer#update(MERGE)
  call gita#meta#set('filename', abspath)
  setlocal buftype=acwrite noswapfile
  setlocal modified
  augroup vim-gita-conflict-solve3
    autocmd! * <buffer>
    autocmd BufWriteCmd <buffer> call s:ac_BufWriteCmd()
  augroup END
  diffthis
  let MERGE_bufnum = bufnr('%')

  " LOCAL
  execute printf('%swincmd w', bufwinnr(MERGE_bufnum))
  call gita#utils#buffer#open(LOCAL_bufname, {
        \ 'group': 'conflict3_local',
        \ 'range': get(options, 'range', 'tabpage'),
        \ 'opener': printf('leftabove %s%s',
        \   get(options, 'vertical') ? 'vertical ' : '',
        \   get(options, 'opener2', 'split'),
        \ ),
        \})
  call gita#utils#buffer#update(LOCAL)
  call gita#meta#set('filename', abspath)
  setlocal buftype=nofile noswapfile
  setlocal nomodifiable readonly
  diffthis
  let LOCAL_bufnum = bufnr('%')

  " REMOTE
  execute printf('%swincmd w', bufwinnr(MERGE_bufnum))
  call gita#utils#buffer#open(REMOTE_bufname, {
        \ 'group': 'conflict3_remote',
        \ 'range': get(options, 'range', 'tabpage'),
        \ 'opener': printf('rightbelow %s%s',
        \   get(options, 'vertical') ? 'vertical ' : '',
        \   get(options, 'opener2', 'split'),
        \ ),
        \})
  call gita#utils#buffer#update(REMOTE)
  call gita#meta#set('filename', abspath)
  setlocal buftype=nofile noswapfile
  setlocal nomodifiable readonly
  diffthis
  let REMOTE_bufnum = bufnr('%')

  " Assign variables and mappings which require XXXXX_bufnum
  " LOCAL
  execute printf('%swincmd w', bufwinnr(LOCAL_bufnum))
  execute printf(join([
        \   'noremap <buffer><silent> <Plug>(gita-action-diffput)',
        \   ':diffput %s<BAR>diffupdate<CR>',
        \ ]),
        \ MERGE_bufnum,
        \)
  nmap <buffer> dp <Plug>(gita-action-diffput)
  let b:_gita_MERGE_bufnum  = MERGE_bufnum
  let b:_gita_REMOTE_bufnum = REMOTE_bufnum

  " REMOTE
  execute printf('%swincmd w', bufwinnr(REMOTE_bufnum))
  execute printf(join([
        \   'noremap <buffer><silent> <Plug>(gita-action-diffput)',
        \   ':diffput %s<BAR>diffupdate<CR>',
        \ ]),
        \ MERGE_bufnum,
        \)
  nmap <buffer> dp <Plug>(gita-action-diffput)
  let b:_gita_MERGE_bufnum = MERGE_bufnum
  let b:_gita_LOCAL_bufnum = LOCAL_bufnum

  " MERGE
  execute printf('%dwincmd w', bufwinnr(MERGE_bufnum))
  execute printf(join([
        \   'noremap <buffer><silent> <Plug>(gita-action-diffget-LOCAL)',
        \   ':diffget %s<BAR>diffupdate<CR>',
        \ ]),
        \ LOCAL_bufnum,
        \)
  execute printf(join([
        \   'noremap <buffer><silent> <Plug>(gita-action-diffget-REMOTE)',
        \   ':diffget %s<BAR>diffupdate<CR>',
        \ ]),
        \ REMOTE_bufnum,
        \)
  nmap <buffer> dol <Plug>(gita-action-diffget-LOCAL)
  nmap <buffer> dor <Plug>(gita-action-diffget-REMOTE)
  let b:_gita_LOCAL_bufnum  = LOCAL_bufnum
  let b:_gita_REMOTE_bufnum = REMOTE_bufnum

  wincmd =
  diffupdate
endfunction " }}}

function! gita#features#conflict#show(...) abort " {{{
  let gita = gita#get()
  if gita.fail_on_disabled()
    return
  endif
  let options = get(a:000, 0, {})
  if empty(get(options, 'file', '')) && empty(get(options, 'status', {}))
    let options.file = '%'
  endif
  if s:ensure_status_option(options)
    return
  endif

  if get(options, 'split', 3) == 2
    call s:solve2(options)
  else
    call s:solve3(options)
  endif
  let line_start = gita#utils#eget(options, 'line_start', line('.'))
  keepjumps call setpos('.', [0, line_start, 0, 0])
  keepjumps normal z.
endfunction " }}}
function! gita#features#conflict#command(bang, range, ...) abort " {{{
  let options = s:parser.parse(a:bang, a:range, get(a:000, 0, ''))
  if !empty(options)
    let options = extend(
          \ deepcopy(g:gita#features#conflict#default_options),
          \ options)
    call gita#action#exec('conflict', options.__range__, options)
  endif
endfunction " }}}
function! gita#features#conflict#complete(arglead, cmdline, cursorpos) abort " {{{
  return s:parser.complete(a:arglead, a:cmdline, a:cursorpos)
endfunction " }}}
function! gita#features#conflict#action(candidates, options, config) abort " {{{
  let candidate = get(a:candidates, 0, {})
  if empty(candidate)
    return
  endif
  call gita#utils#anchor#focus()
  call gita#features#conflict#show(extend({
        \ 'status': get(candidate, 'status', {}),
        \ 'file': gita#utils#sget([a:options, candidate], 'path'),
        \ 'line_start': gita#utils#sget([a:options, candidate], 'line_start'),
        \ 'line_end': gita#utils#sget([a:options, candidate], 'line_end'),
        \}, a:options))
endfunction " }}}

let &cpoptions = s:save_cpoptions
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
