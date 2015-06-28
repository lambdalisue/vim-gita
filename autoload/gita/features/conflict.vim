let s:save_cpo = &cpo
set cpo&vim

let s:P = gita#utils#import('Prelude')
let s:C = gita#utils#import('VCS.Git.Conflict')


function! s:complete_conflicted_file(arglead, cmdline, cursorpos, ...) abort " {{{
  return []
endfunction " }}}
let s:parser = s:A.new({
      \ 'name': 'Gita[!] conflict',
      \ 'description': 'Solve a conflicted file in merge mode.',
      \})
call s:parser.add_argument(
      \ 'file', [
      \   'A file to solve conflict.',
      \ ], {
      \   'complete': function('s:complete_conflicted_file'),
      \})
call s:parser.add_argument(
      \ '--1way', '-1', [
      \   'Open a single buffer to directly solve the conflict.',
      \ ], {
      \   'conflicts': ['2way', '3way'],
      \})
call s:parser.add_argument(
      \ '--2way', '-2', [
      \   'Open MERGE buffer and REMOTE buffer to solve the conflict.',
      \ ], {
      \   'conflicts': ['2way', '3way'],
      \})
call s:parser.add_argument(
      \ '--3way', '-3', [
      \   'Open MERGE buffer, LOCAL buffer and REMOTE buffer to solve the conflict.',
      \ ], {
      \   'conflicts': ['1way', '2way'],
      \})
function! s:parser.hooks.post_validate(opts) abort " {{{
  if get(a:opts, '1way')
    unlet a:opts['1way']
    let a:opts.way = 1
  elseif get(a:opts, '1way')
    unlet a:opts['2way']
    let a:opts.way = 2
  else
    silent! unlet a:opts['3way']
    let a:opts.way = 3
  endif
endfunction " }}}
function! s:solve1(...) abort " {{{
  call gita#utils#error(
        \ 'This feature is not implemented yet.',
        \)
endfunction " }}}
function! s:solve2(...) abort " {{{
  let gita = gita#core#get()
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

  let MERGE_bufname = abspath
  let REMOTE_bufname = gita#utils#buffer#bufname(
        \ abspath,
        \ 'REMOTE',
        \)
  let bufnums = gita#utils#buffer#open2(
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
  setlocal nomodifiable readonly
  let b:_gita_original_filename = abspath
  diffthis

  " MERGE
  execute printf('%swincmd w', bufwinnr(MERGE_bufnum))
  diffthis
  diffupdate
endfunction " }}}
function! s:solve3(...) abort " {{{
  let gita = gita#core#get()
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
  setlocal buftype=nofile bufhidden=wipe noswapfile
  setlocal nomodifiable readonly
  execute printf(join([
        \   'noremap <buffer><silent> <Plug>(gita-action-diffput)',
        \   ':<C-u>diffput %s<CR>',
        \ ]),
        \ MERGE_bufnum,
        \)
  nmap <buffer> dp <Plug>(gita-action-diffput)
  diffthis

  " REMOTE
  execute printf('%swincmd w', bufwinnr(REMOTE_bufnum))
  call gita#utils#buffer#update(REMOTE)
  setlocal buftype=nofile bufhidden=wipe noswapfile
  setlocal nomodifiable readonly
  execute printf(join([
        \   'noremap <buffer><silent> <Plug>(gita-action-diffput)',
        \   ':<C-u>diffput %s<CR>',
        \ ]),
        \ MERGE_bufnum,
        \)
  nmap <buffer> dp <Plug>(gita-action-diffput)
  diffthis

  " MERGE
  execute printf('%swincmd w', bufwinnr(MERGE_bufnum))
  call gita#utils#buffer#update(MERGE)
  call setbufvar(MERGE_bufnum, '_gita_original_filename', path)
  call setbufvar(MERGE_bufnum, '_gita_LOCAL_bufnum', LOCAL_bufnum)
  call setbufvar(MERGE_bufnum, '_gita_REMOTE_bufnum', REMOTE_bufnum)
  setlocal buftype=acwrite bufhidden=wipe noswapfile
  execute printf(join([
        \   'noremap <buffer><silent> <Plug>(gita-action-diffget-LOCAL)',
        \   ':<C-u>diffget %s<CR>',
        \ ]),
        \ LOCAL_bufnum,
        \)
  execute printf(join([
        \   'noremap <buffer><silent> <Plug>(gita-action-diffget-REMOTE)',
        \   ':<C-u>diffget %s<CR>',
        \ ]),
        \ REMOTE_bufnum,
        \)
  nmap <buffer> dol <Plug>(gita-action-diffget-LOCAL)
  nmap <buffer> dor <Plug>(gita-action-diffget-REMOTE)
  augroup vim-gita-conflict
    autocmd! * <buffer>
    autocmd BufWriteCmd <buffer> call s:ac_BufWriteCmd()
    autocmd QuitPre     <buffer> call s:ac_QuitPre()
    autocmd BufWinLeave <buffer> call s:ac_BufWinLeave()
  augroup END
  diffthis

  wincmd =
  diffupdate
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
function! s:ac_QuitPre() abort " {{{
  let b:_gita_QuitPre = 1
endfunction " }}}
function! s:ac_BufWinLeave() abort " {{{
  let expr = expand('<afile>')
  if getbufvar(expr, '_gita_QuitPre')
    call setbufvar(expr, '_gita_QuitPre', 0)
    let LOCAL_bufnum = getbufvar(expr, '_gita_LOCAL_bufnum')
    let REMOTE_bufnum = getbufvar(expr, '_gita_REMOTE_bufnum')
    for bufnum in [LOCAL_bufnum, REMOTE_bufnum]
      if bufexists(bufnum)
        execute printf('noautocmd %dwincmd w', bufwinnr(bufnum))
        diffoff
        silent noautocmd bwipe!
      endif
    endfor
  endif
endfunction " }}}

function! gita#features#conflict#show(...) abort " {{{
  let gita = gita#core#get()
  if gita.fail_on_disabled()
    return
  endif

  let options = get(a:000, 0, {})
  if !has_key(options, 'status') && !has_key(options, 'file')
    call gita#utils#error(
          \ '"status" nor "file" is specified.',
          \)
    return
  elseif has_key(options, 'status')
    let options.file = get(options.status, 'path2', options.status.path)
  else
    let options.status = gita#utils#get_status(options.file)
  endif

  let way = get(options, 'way', 3)
  if way == 3
    call s:solve3(options)
  elseif way == 2
    call s:solve2(options)
  elseif way == 1
    call s:solve1(options)
  endif
endfunction " }}}
function! gita#features#conflict#command(bang, range, ...) abort " {{{
  let options = s:parser.parse(a:bang, a:range, get(a:000, 0, ''))
  if !empty(options)
    call gita#features#conflict#show(options)
  endif
endfunction " }}}
function! gita#features#conflict#complete(arglead, cmdline, cursorpos) abort " {{{
  return s:parser.complete(a:arglead, a:cmdline, a:cursorpos)
endfunction " }}}

let &cpo = s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
