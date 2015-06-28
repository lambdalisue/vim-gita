let s:save_cpo = &cpo
set cpo&vim


let s:D = gita#utils#import('Data.Dict')
let s:A = gita#utils#import('ArgumentParser')


function! s:complete_commit(arglead, cmdline, cursorpos, ...) abort " {{{
  let arglead = substitute(a:arglead, '^.*\.\.\.\?', '', '')
  return call('gita#completes#complete_local_branch', extend(
        \ [arglead, a:cmdline, a:cursorpos],
        \ a:000,
        \))
endfunction " }}}
let s:parser = s:A.new({
      \ 'name': 'Gita diff',
      \ 'description': 'Show changes between commits, commit and working tree, etc',
      \})
call s:parser.add_argument(
      \ 'commit', [
      \   'A commit which you want to compare with.',
      \   'If nothing is specified, it show changes in working tree relative to the index (staging area for next commit).',
      \   'If <commit> is specified, it show changes in working tree relative to the named <commit>.',
      \   'If <commit>..<commit> is specified, it show the changes between two arbitrary <commit>.',
      \   'If <commit>...<commit> is specified, it show thechanges on the branch containing and up to the second <commit>, starting at a common ancestor of both <commit>.',
      \ ], {
      \   'complete': function('s:complete_commit'),
      \ })
call s:parser.add_argument(
      \ '--cached',
      \ 'Compare the changes you staged for the next commit relative to the named <commit> or HEAD', {
      \   'conflicts': ['no_index'],
      \ })
call s:parser.add_argument(
      \ '--compare', '-c',
      \ 'Compare the changes in diff mode',
      \ )
call s:parser.add_argument(
      \ '--opener', '-o', [
      \   'A way to open a new buffer such as "edit", "split", or etc.',
      \ ], {
      \ 'type': s:A.types.value,
      \ },
      \)
call s:parser.add_argument(
      \ '--vertical', '-v', [
      \   'Vertically open a second buffer (vsplit).',
      \   'If it is omitted, the buffer is opened horizontally (split).',
      \ ], {
      \ 'superordinates': ['compare'],
      \ },
      \)

function! s:diff(...) abort " {{{
  let gita = gita#core#get()
  let options = get(a:000, 0, {})
  if gita.fail_on_disabled()
    return
  endif
  let options.no_prefix = 1
  let options.no_color = 1
  let options.unified = '0'
  let options.histogram = 1

  let result = gita#features#diff#exec(options, {
        \ 'echo': 'fail',
        \})
  if result.status != 0
    return
  endif

  if len(get(options, '--', [])) == 1
    let DIFF_bufname = gita#utils#buffer#bufname(
          \ printf('%s.diff', options['--'][0]),
          \ has('unix') ? options.commit : substitute(options.commit, ':', '-', 'g'),
          \)
  else
    let DIFF_bufname = gita#utils#buffer#bufname(
          \ 'diff',
          \ has('unix') ? options.commit : substitute(options.commit, ':', '-', 'g'),
          \)
  endif
  let DIFF = split(result.stdout, '\v\r?\n')
  let opener = get(options, 'opener', 'edit')
  call gita#utils#buffer#open(DIFF_bufname, '', {
        \ 'opener': opener,
        \})
  call gita#utils#buffer#update(DIFF)
  setlocal buftype=nofile bufhidden=wipe noswapfile
  setlocal nomodifiable
  setlocal filetype=diff
endfunction " }}}
function! s:compare(...) abort " {{{
  let gita = gita#core#get()
  let options = get(a:000, 0, {})
  " validate 'file'
  if len(get(options, '--', [])) == 0
    " Use a current buffer
    let options['--'] = ['%']
  elseif len(get(options, '--', [])) > 1
    call gita#utils#warn(
          \ 'A single file required to be specified to compare the difference.',
          \)
    return
  endif
  let options.file = gita#utils#expand(options['--'][0])

  " find commit1 and commit2
  let commit1_display = ''
  let commit2_display = ''
  if options.commit =~# '\v^.*\.\.\..*$'
    " find a common ancestor
    let [lhs, rhs] = matchlist(options.commit, '\v^(.*)\.\.\.(.*)$')[1 : 2]
    let lhs = empty(lhs) ? 'HEAD' : lhs
    let rhs = empty(rhs) ? 'HEAD' : rhs
    let result = gita.operations.merge_base({ '--': [lhs, rhs] }, {
          \ 'echo': 'fail',
          \})
    if result.status != 0
      return
    endif
    let commit1 = result.stdout
    let commit2 = empty(rhs) ? 'HEAD' : rhs
    let result = gita.operations.rev_parse({ 'short': 1, 'args': result.stdout }, {
          \ 'echo': 'fail',
          \})
    if result.status == 0
      " use user-friendly name
      let commit1_display = printf('ANCESTOR:%s', result.stdout)
    endif
  elseif options.commit =~# '\v^.*\.\..*$'
    let [lhs, rhs] = matchlist(options.commit, '\v^(.*)\.\.(.*)$')[1 : 2]
    let commit1 = empty(lhs) ? 'HEAD' : lhs
    let commit2 = empty(rhs) ? 'HEAD' : rhs
  else
    let commit1 = 'WORKTREE'
    let commit2 = options.commit
  endif
  let commit1_display = empty(commit1_display) ? commit1 : commit1_display
  let commit2_display = empty(commit2_display) ? commit2 : commit2_display

  " commit1
  let result = gita#features#file#exec({ 'commit': commit1, 'file': options.file }, {
        \ 'echo': '',
        \})
  if result.status == 0
    let COMMIT1 = split(result.stdout, '\v\r?\n')
  else
    let COMMIT1 = []
  endif
  if commit1 ==# 'WORKTREE'
    let COMMIT1_bufname = options.file
  else
    let COMMIT1_bufname = gita#utils#buffer#bufname(
          \ options.file,
          \ has('unix') ? commit1_display : substitute(commit1_display, ':', '-', 'g'),
          \)
  endif
  " commit2
  let result = gita#features#file#exec({ 'commit': commit2, 'file': options.file }, {
        \ 'echo': '',
        \})
  if result.status == 0
    let COMMIT2 = split(result.stdout, '\v\r?\n')
  else
    let COMMIT2 = []
  endif
  if commit2 ==# 'WORKTREE'
    let COMMIT2_bufname = options.file
  else
    let COMMIT2_bufname = gita#utils#buffer#bufname(
          \ options.file,
          \ has('unix') ? commit2_display : substitute(commit2_display, ':', '-', 'g'),
          \)
  endif

  let bufnums = gita#utils#buffer#open2(
        \ COMMIT1_bufname, COMMIT2_bufname, 'vim_gita_diff', {
        \   'opener': get(options, 'opener', 'edit'),
        \   'vertical': get(options, 'vertical', 0),
        \})
  let COMMIT1_bufnum = bufnums.bufnum1
  let COMMIT2_bufnum = bufnums.bufnum2

  " COMMIT1
  execute printf('%swincmd w', bufwinnr(COMMIT1_bufnum))
  if commit1 !=# 'WORKTREE'
    call gita#utils#buffer#update(COMMIT1)
    setlocal buftype=nofile bufhidden=wipe noswapfile
    setlocal nomodifiable
    let b:_gita_original_filename = options.file
  endif
  diffthis

  " COMMIT2
  execute printf('%swincmd w', bufwinnr(COMMIT2_bufnum))
  if commit2 !=# 'WORKTREE'
    call gita#utils#buffer#update(COMMIT2)
    setlocal buftype=nofile bufhidden=wipe noswapfile
    setlocal nomodifiable
    let b:_gita_original_filename = options.file
  endif
  diffthis
  diffupdate
endfunction " }}}

function! gita#features#diff#exec(...) abort " {{{
  let gita = gita#core#get()
  let options = deepcopy(get(a:000, 0, {}))
  let config = get(a:000, 1, {})
  if gita.fail_on_disabled()
    return { 'status': -1 }
  endif
  if !empty(get(options, '--', []))
    call map(options['--'], 'gita#utils#expand(v:val)')
  endif
  if has_key(options, 'commit')
    let options.commit = substitute(options.commit, 'INDEX', '', 'g')
  endif
  let options = s:D.pick(options, [
        \ '--',
        \ 'ignore_submodules',
        \ 'no_prefix',
        \ 'no_color',
        \ 'unified',
        \ 'histogram',
        \ 'no_index',
        \ 'cached',
        \ 'commit',
        \ 'name_status',
        \])
  return gita.operations.diff(options, config)
endfunction " }}}
function! gita#features#diff#show(...) abort " {{{
  let options = get(a:000, 0, {})
  if !has_key(options, 'commit')
    let commit = gita#utils#ask(
          \ 'Which commit do you want to compare with? (e.g INDEX, HEAD, master, master.., master..., etc.)',
          \ 'INDEX',
          \)
    if empty(commit)
      call gita#utils#warn(
            \ 'The operation has canceled by user',
            \)
      return
    endif
    let options.commit = commit
  endif
  let config = get(a:000, 1, {})
  if get(options, 'compare')
    call s:compare(options, config)
  else
    call s:diff(options, config)
  endif
endfunction " }}}
function! gita#features#diff#command(bang, range, ...) abort " {{{
  let options = s:parser.parse(a:bang, a:range, get(a:000, 0, ''))
  if !empty(options)
    let options = extend(options, {
          \ '--': options.__unknown__,
          \})
    call gita#features#diff#show(options)
  endif
endfunction " }}}
function! gita#features#diff#complete(arglead, cmdline, cursorpos) abort " {{{
  return s:parser.complete(a:arglead, a:cmdline, a:cursorpos)
endfunction " }}}

let &cpo = s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
