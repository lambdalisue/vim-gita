let s:save_cpo = &cpo
set cpo&vim

let s:A = gita#utils#import('ArgumentParser')


function! s:complete_commit(arglead, cmdline, cursorpos, ...) abort " {{{
  let candidates = gita#completes#complete_local_branch()
  return extend(['WORKTREE', 'INDEX'], candidates)
endfunction " }}}
let s:parser = s:A.new({
      \ 'name': 'Gita file',
      \ 'description': [
      \   'Show a file content of a working tree, index, or specified commit.',
      \ ],
      \})
call s:parser.add_argument(
      \ '--opener', '-o', [
      \   'A way to open a new buffer such as "edit", "split", or etc.',
      \ ], {
      \ 'type': s:A.types.value,
      \ },
      \)
call s:parser.add_argument(
      \ 'commit', [
      \   'A commit-ish which you want to show.',
      \   'If you specify WORKTREE, it show the content of the current working tree.',
      \   'If you specify INDEX, it show the content of the current index (staging area for next commit).',
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

function! gita#features#file#exec(...) abort " {{{
  let gita = gita#core#get()
  let options = get(a:000, 0, {})
  let config = get(a:000, 1, {})
  if gita.fail_on_disabled()
    return { 'status': -1 }
  endif

  let file = expand(options.file)
  let commit = options.commit

  if commit ==# 'WORKTREE'
    if filereadable(file)
      return {
            \ 'status': 0,
            \ 'stdout': join(readfile(file), "\n"),
            \}
    else
      let errormsg = printf('%s is not in working tree.', file)
      call gita#utils#warn(errormsg)
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
          \ 'Which commit do you want to show? (e.g. WORKTREE, INDEX, HEAD, master) ',
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
          \ options.commit,
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
