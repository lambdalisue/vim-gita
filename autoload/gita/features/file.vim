let s:save_cpo = &cpo
set cpo&vim

let s:A = gita#utils#import('ArgumentParser')


function! s:complete_commit(arglead, cmdline, cursorpos, ...) abort " {{{
  let leading = matchstr(a:arglead, '^.*\.\.\.')
  let arglead = substitute(a:arglead, '^.*\.\.\.', '', '')
  let candidates = call('gita#utils#completes#complete_local_branch', extend(
        \ [arglead, a:cmdline, a:cursorpos],
        \ a:000,
        \))
  let candidates = extend(['WORKTREE', 'INDEX', 'HEAD', 'FORK:master'], candidates)
  let candidates = map(candidates, 'leading . v:val')
  return candidates
endfunction " }}}
let s:parser = s:A.new({
      \ 'name': 'Gita[!] file',
      \ 'description': 'Show a file content of a working tree, index, or specified commit.',
      \})
call s:parser.add_argument(
      \ 'commit', [
      \   'A Gita specialized commit-ish which you want to show. The followings are Gita special terms:',
      \   'WORKTREE  it show the content of the current working tree.',
      \   'INDEX  it show the content of the current index (staging area for next commit).',
      \   '<commit>...<commit>  it show the content of the fork point between <commit>.',
      \ ], {
      \   'complete': function('s:complete_commit'),
      \})
call s:parser.add_argument(
      \ 'file', [
      \   'A filepath which you want to see the content.',
      \   'If it is omitted and the current buffer is a file',
      \   'buffer, the current buffer will be used.',
      \ ],
      \)
call s:parser.add_argument(
      \ '--opener', '-o', [
      \   'A way to open a new buffer such as "edit", "split", or etc.',
      \ ], {
      \ 'type': s:A.types.value,
      \ },
      \)
call s:parser.add_argument(
      \ '--ancestor', '-1', [
      \   'During a merge, show a common ancestor of a conflicted file.',
      \   'It is a synonyum of specifing :1 to <commit> and overwrite a specified <commit>.',
      \ ], {
      \   'conflicts': ['ours', 'theirs'],
      \ }
      \)
call s:parser.add_argument(
      \ '--ours', '-2', [
      \   'During a merge, show a target branch''s version of a conflicted file.',
      \   'It is a synonyum of specifing :2 to <commit> and overwrite a specified <commit>.',
      \ ], {
      \   'conflicts': ['ancestor', 'theirs'],
      \ }
      \)
call s:parser.add_argument(
      \ '--theirs', '-3', [
      \   'During a merge, show a version from the branch which is being merged of a conflicted file.',
      \   'It is a synonyum of specifing :3 to <commit> and overwrite a specified <commit>.',
      \ ], {
      \   'conflicts': ['ours', 'ancestor'],
      \ }
      \)
function! s:parser.hooks.post_validate(opts) abort " {{{
  if get(a:opts, 'ancestor')
    unlet! a:opts.ancestor
    let a:opts.commit = ':1'
  elseif get(a:opts, 'ours')
    unlet! a:opts.ours
    let a:opts.commit = ':2'
  elseif get(a:opts, 'theirs')
    unlet! a:opts.theirs
    let a:opts.commit = ':3'
  endif
endfunction " }}}
function! s:ensure_file_option(options) abort " {{{
  if empty(get(a:options, 'file'))
    let filename = gita#utils#expand('%')
    if empty(filename)
      call gita#utils#warn(
            \ 'No file is specified and could not automatically detect.'
            \)
      call gita#utils#info(
            \ 'Operation has canceled.'
            \)
      return -1
    endif
    let a:options.file = '%'
  endif
  let a:options.file = gita#utils#expand(a:options.file)
  return 0
endfunction " }}}
function! s:ensure_commit_option(options) abort " {{{
  if empty(get(a:options, 'commit', ''))
    let meta = gita#get_meta()
    let commit = gita#utils#ask(
          \ 'Which commit do you want to show? (e.g. WORKTREE, INDEX, HEAD, master..., master, etc.) ',
          \ get(meta, 'commit', 'INDEX'),
          \)
    if empty(commit)
      call gita#utils#info(
            \ 'Operation has canceled by user',
            \)
      return -1
    endif
    let a:options.commit = commit
  endif

  if a:options.commit =~# '\v^[^.]*\.\.[^.]*$'
    let [lhs, rhs] = matchlist(
          \ a:options.commit,
          \ '\v^([^.]*)\.\.([^.]*)$',
          \)[1 : 2]
    let a:options.commit = lhs
  endif
  return 0
endfunction " }}}
function! s:translate_commit(commit, ...) abort " {{{
  let config = extend({
        \ 'echo': 'both',
        \}, get(a:000, 0, {}))
  if a:commit =~# '\v^[^.]*\.\.\.[^.]*$'
    let [lhs, rhs] = matchlist(a:commit, '\v^([^.]*)\.\.\.([^.]*)$')[1 : 2]
    let lhs = empty(lhs) ? 'HEAD' : lhs
    let rhs = empty(rhs) ? 'HEAD' : rhs
    let gita = gita#get()
    let result = gita.operations.merge_base({
          \ 'commit1': lhs,
          \ 'commit2': rhs,
          \}, {
          \ 'echo': '',
          \})
    if result.status
      if config.echo =~# '^\%(both\|fail\)$'
        call gita#utils#error(printf(
              \ 'Fail: %s', join(result.args),
              \))
        call gita#utils#info(result.stdout)
        call gita#utils#info(printf(
              \ 'A fork point between "%s" and "%s" could not be found.',
              \ lhs, rhs,
              \))
      endif
      return ''
    endif
    return result.stdout
  else
    return empty(a:commit) ? 'INDEX' : a:commit
  endif
endfunction " }}}

function! gita#features#file#exec(...) abort " {{{
  let gita = gita#get()
  let options = get(a:000, 0, {})
  let config = extend({
        \ 'echo': 'both',
        \}, get(a:000, 1, {}))
  if gita.fail_on_disabled()
    return { 'status': -1 }
  endif

  let file = gita#utils#expand(options.file)
  let commit = s:translate_commit(options.commit, config)
  if empty(commit)
    return {
          \ 'status': -1,
          \ 'stdout': printf(
          \   'A fork point of "%s" could not be found.',
          \   options.commit,
          \ )
          \}
  endif

  if commit ==# 'WORKTREE'
    let abspath = gita.git.get_absolute_path(file)
    if filereadable(abspath)
      return {
            \ 'status': 0,
            \ 'stdout': join(readfile(abspath), "\n"),
            \}
    else
      let errormsg = printf('%s is not readable.', file)
      if config.echo =~# '\%(both\|fail\)'
        call gita#utils#error(errormsg)
      endif
      return {
            \ 'status': -1,
            \ 'stdout': errormsg,
            \}
    endif
  else
    return gita.operations.show({
          \ 'object': printf('%s:%s',
          \   substitute(commit, '\v\.?\zsINDEX\ze\.?$', '', ''),
          \   gita.git.get_relative_path(file),
          \ ),
          \}, config)
  endif
endfunction " }}}
function! gita#features#file#show(...) abort " {{{
  let gita = gita#get()
  let options = get(a:000, 0, {})
  if s:ensure_file_option(options)
    return
  endif
  if s:ensure_commit_option(options)
    return
  endif
  let result = gita#features#file#exec(options, {
        \ 'echo': 'fail',
        \})
  if result.status
    return
  endif

  if options.commit ==# 'WORKTREE'
    let bufname = options.file
  else
    let bufname = gita#utils#buffer#bufname(
          \ options.commit,
          \ options.file,
          \)
  endif
  call gita#utils#buffer#open(bufname, '', {
        \ 'opener': get(options, 'opener', 'edit'),
        \})
  if options.commit !=# 'WORKTREE'
    setlocal buftype=nofile bufhidden=hide noswapfile
    setlocal nomodifiable readonly
    call gita#utils#buffer#update(
          \ split(result.stdout, '\v\r?\n')
          \)
  endif
  call gita#set_meta({
        \ 'file': options.file,
        \ 'commit': options.commit,
        \})
endfunction " }}}
function! gita#features#file#command(bang, range, ...) abort " {{{
  let options = s:parser.parse(a:bang, a:range, get(a:000, 0, ''))
  if !empty(options)
    let options = extend(
          \ g:gita#features#file#default_options,
          \ options)
    call gita#features#file#show(options)
  endif
endfunction " }}}
function! gita#features#file#complete(arglead, cmdline, cursorpos) abort " {{{
  return s:parser.complete(a:arglead, a:cmdline, a:cursorpos)
endfunction " }}}

let &cpo = s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
