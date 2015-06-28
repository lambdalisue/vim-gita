let s:save_cpo = &cpo
set cpo&vim

let s:A = gita#utils#import('ArgumentParser')


function! s:complete_commit(arglead, cmdline, cursorpos, ...) abort " {{{
  let candidates = call('gita#completes#complete_local_branch', extend(
        \ [a:arglead, a:cmdline, a:cursorpos], a:000,
        \))
  return extend(['WORKTREE', 'INDEX', 'FORK:master'], candidates)
endfunction " }}}
let s:parser = s:A.new({
      \ 'name': 'Gita file',
      \ 'description': 'Show a file content of a working tree, index, or specified commit.',
      \})
call s:parser.add_argument(
      \ 'commit', [
      \   'A Gita specialized commit-ish which you want to show. The followings are Gita special terms:',
      \   'WORKTREE      it show the content of the current working tree.',
      \   'INDEX         it show the content of the current index (staging area for next commit).',
      \   'FORK:<commit> it show the content of the fork point from <commit>.',
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

function! gita#features#file#exec(...) abort " {{{
  let gita = gita#core#get()
  let options = get(a:000, 0, {})
  let config = extend({
        \ 'echo': 'both',
        \}, get(a:000, 1, {}))
  if gita.fail_on_disabled()
    return { 'status': -1 }
  endif

  let file = expand(options.file)
  let commit = options.commit

  if commit =~# '^FORK:'
    " find a fork point and use that
    let ref = matchstr(commit, '^FORK:\zs.*$')
    let result = gita.operations.merge_base({ 'fork_point': ref }, {
          \ 'echo': '',
          \})
    if result.status != 0
      if config.echo =~# '\%(both\|fail\)'
        call gita#utils#error(printf(
              \ 'Fail: %s', join(result.args),
              \))
        call gita#utils#info(printf(
              \ 'A fork point from %s could not be found.', ref
              \))
        call gita#utils#info(result.stdout)
      endif
      return result
    endif
    let commit = result.stdout
  endif

  if commit ==# 'WORKTREE'
    if filereadable(file)
      return {
            \ 'status': 0,
            \ 'stdout': join(readfile(file), "\n"),
            \}
    else
      let errormsg = printf('%s is not in working tree.', file)
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
          \   substitute(commit, '^INDEX$', '', ''),
          \   gita.git.get_relative_path(file),
          \ ),
          \}, config)
  endif
endfunction " }}}
function! gita#features#file#show(...) abort " {{{
  let options = get(a:000, 0, {})
  " ensure file option
  if empty(get(options, 'file', ''))
    if !empty(&buftype) && empty(get(b:, '_gita_original_filename'))
      call gita#utils#error(
            \ 'The current buffer is not a file buffer.',
            \)
      call gita#utils#info(
            \ 'Operation has canceled.'
            \)
      return
    endif
    let options.file = '%'
  endif
  let options.file = gita#utils#expand(options.file)
  " ensure commit
  if empty(get(options, 'commit', ''))
    let commit = gita#utils#ask(
          \ 'Which commit do you want to show? (e.g. WORKTREE, INDEX, HEAD, FORK:master, master, etc.) ',
          \ 'INDEX',
          \)
    if empty(commit)
      call gita#utils#info(
            \ 'The operation has canceled by user',
            \)
      return
    endif
    let options.commit = commit
  endif

  let result = gita#features#file#exec(options, {
        \ 'echo': 'fail',
        \})
  if result.status != 0
    return
  endif

  let CONTENTS = split(result.stdout, '\v\r?\n')
  if options.commit ==# 'WORKTREE'
    let bufname = options.file
  else
    let bufname = gita#utils#buffer#bufname(
          \ options.file,
          \ has('unix') ? options.commit : substitute(options.commit, ':', '-', 'g'),
          \)
  endif
  let opener = get(options, 'opener', 'edit')
  call gita#utils#buffer#open(bufname, '', {
        \ 'opener': opener,
        \})
  if options.commit !=# 'WORKTREE'
    setlocal modifiable
    call gita#utils#buffer#update(CONTENTS)
    setlocal buftype=nofile bufhidden=wipe noswapfile
    setlocal nomodifiable
    let b:_gita_original_filename = options.file
  endif
endfunction " }}}
function! gita#features#file#command(bang, range, ...) abort " {{{
  let options = s:parser.parse(a:bang, a:range, get(a:000, 0, ''))
  if !empty(options)
    call gita#features#file#show(options)
  endif
endfunction " }}}
function! gita#features#file#complete(arglead, cmdline, cursorpos) abort " {{{
  return s:parser.complete(a:arglead, a:cmdline, a:cursorpos)
endfunction " }}}

let &cpo = s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
