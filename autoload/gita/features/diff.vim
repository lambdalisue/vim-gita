let s:save_cpo = &cpo
set cpo&vim


let s:A = gita#utils#import('ArgumentParser')


function! s:ensure_commit(options) abort " {{{
  if empty(get(a:options, 'commit')) || get(a:options, 'new')
    let commit = gita#utils#ask(
          \ 'Which commit do you want to compare with? ',
          \ get(a:options, 'commit', 'HEAD'),
          \)
    if empty(commit)
      call gita#utils#info('Operation has canceled by user')
      return 0
    endif
  else
    let commit = a:options.commit
  endif
  " Note:
  "   A value of 'commit' might contains leading/trailing dots
  "   like 'master...' or '..master' or whatever
  let commit = substitute(commit, '\%(^\.\+\|\.\+$\)', '', 'g')
  let commit = substitute(commit, '^INDEX$', '', '')
  let a:options.commit = commit
  return 1
endfunction " }}}


let s:parser = s:A.new({
      \ 'name': 'Gita diff',
      \ 'description': 'Show a difference of a file',
      \})
call s:parser.add_argument(
      \ 'commit',
      \ 'A commit string to specify how to compare the versions', {
      \   'complete': function('gita#completes#complete_local_branch'),
      \ })
call s:parser.add_argument(
      \ '--single', '-1',
      \ 'Open a single buffer to show the difference', {
      \   'conflicts': ['double'],
      \ })
call s:parser.add_argument(
      \ '--double', '-2',
      \ 'Open double buffers to compare the difference', {
      \   'conflicts': ['single'],
      \ })
function! s:parser.hooks.pre_validate(options) abort " {{{
  " Automatically use '--singe' if no conflicted argument is specified
  if empty(self.get_conflicted_arguments('single', a:options))
    let a:options.single = 1
  endif
endfunction " }}}


function! gita#features#diff#single(path, ...) abort " {{{
  let gita = gita#core#get(a:path)
  if !gita.enabled
    redraw
    call gita#utils#warn(
          \ 'Gita is not available in the current buffer.',
          \)
    return
  endif

  let options = get(a:000, 0, {})
  if !s:ensure_commit(options)
    return
  endif
  let abspath = gita.git.get_absolute_path(a:path)
  let relpath = gita.git.get_relative_path(a:path)
  " TODO: Add user options
  let result = gita.operations.diff({
        \ 'ignore_submodules': 1,
        \ 'no_prefix': 1,
        \ 'no_color': 1,
        \ 'unified': '0',
        \ 'histogram': 1,
        \ 'commit': options.commit,
        \ '--': [abspath],
        \}, {
        \ 'echo': 'fail',
        \})
  if result.status != 0
    return
  endif

  let DIFF = split(result.stdout, '\v\r?\n')
  let DIFF_bufname = gita#utils#buffer#bufname(
        \ printf('%s.diff', relpath),
        \ empty(options.commit) ? 'INDEX' : options.commit,
        \)
  let opener = get(options, 'opener', 'edit')
  call gita#utils#buffer#open(DIFF_bufname, '', {
        \ 'opener': opener,
        \})
  call gita#utils#buffer#update(DIFF)
  setlocal buftype=nofile bufhidden=wipe noswapfile
  setlocal nomodifiable
endfunction " }}}
function! gita#features#diff#double(path, ...) abort " {{{
  let gita = gita#core#get(a:path)
  if !gita.enabled
    redraw
    call gita#utils#warn(
          \ 'Gita is not available in the current buffer.',
          \)
    return
  endif

  let options = get(a:000, 0, {})
  if !s:ensure_commit(options)
    return
  endif
  let abspath = gita.git.get_absolute_path(a:path)
  let relpath = gita.git.get_relative_path(a:path)
  " TODO: Add user options
  let result = gita.operations.show({
        \ 'object': printf('%s:%s', options.commit, relpath),
        \}, {
        \ 'echo': '',
        \})
  if result.status != 0
    let REF = split(result.stdout, '\v\r?\n')
  else
    " probably the file does not exists in the version
    " so just show a empty buffer
    let REF = []
  endif

  let LOCAL_bufname = abspath
  let REF_bufname = gita#utils#buffer#bufname(
        \ relpath,
        \ empty(options.commit) ? 'INDEX' : options.commit,
        \)
  let opener = get(options, 'opener', 'edit')

  " Open two buffers
  let bufnums = gita#utils#buffer#diff2(
        \ LOCAL_bufname, REF_bufname, 'diff', {
        \   'opener': get(options, 'opener', 'edit'),
        \   'vertical': get(options, 'vertical', 0),
        \})
  let LOCAL_bufnum = bufnums.bufnum1
  let REF_bufnum   = bufnums.bufnum2

  " REFERENCE
  execute printf('%swincmd w', bufwinnr(REF_bufnum))
  call gita#utils#buffer#update(REF)
  setlocal buftype=nofile bufhidden=wipe noswapfile
  setlocal nomodifiable

  " LOCAL
  execute printf('%swincmd w', bufwinnr(LOCAL_bufnum))
  diffupdate
endfunction " }}}
function! gita#features#diff#command(bang, range, ...) abort " {{{
  let options = s:parser.parse(a:bang, a:range, get(a:000, 0, ''))
  if !empty(options)
    let path = expand(get(options.__unknown__, 0, '%'))
    if get(options, 'single')
      call gita#features#diff#single(path, options)
    elseif get(options, 'double')
      call gita#features#diff#double(path, options)
    endif
  endif
endfunction " }}}
function! gita#features#diff#complete(arglead, cmdline, cursorpos) abort " {{{
  return s:parser.complete(a:arglead, a:cmdline, a:cursorpos)
endfunction " }}}

let &cpo = s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
