let s:save_cpo = &cpo
set cpo&vim


let s:L = gita#import('Data.List')
let s:D = gita#import('Data.Dict')
let s:P = gita#import('System.Filepath')
let s:A = gita#import('ArgumentParser')

function! s:complete_commit(arglead, cmdline, cursorpos, ...) abort " {{{
  let leading = matchstr(a:arglead, '^.*\.\.\.\?')
  let arglead = substitute(a:arglead, '^.*\.\.\.\?', '', '')
  let candidates = call('gita#utils#completes#complete_local_branch', extend(
        \ [arglead, a:cmdline, a:cursorpos],
        \ a:000,
        \))
  let candidates = map(candidates, 'leading . v:val')
  return candidates
endfunction " }}}
let s:parser = s:A.new({
      \ 'name': 'Gita[!] diff',
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
      \ 'file', [
      \   'A filepath which you want to compare the content.',
      \   'If it is omitted and the current buffer is a file',
      \   'buffer, the current buffer will be used for double window mode.',
      \ ],
      \)
call s:parser.add_argument(
      \ '--cached',
      \ 'Compare the changes you staged for the next commit relative to the named <commit> or HEAD', {
      \   'conflicts': ['no_index'],
      \ })
call s:parser.add_argument(
      \ '--ignore-submodules',
      \ 'ignore changes to submodules, optional when: all, dirty, untracked (Default: all)', {
      \   'choices': ['all', 'dirty', 'untracked'],
      \   'on_default': 'all',
      \ })
call s:parser.add_argument(
      \ '--window', '-w',
      \ 'Open single/double window to show the difference (Default: single)', {
      \   'choices': ['single', 'double'],
      \   'default': 'single',
      \ })
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
      \ ],
      \)
function! s:parser.hooks.post_complete_optional_argument(candidates, options) abort " {{{
  let candidates = s:L.flatten([
        \ gita#utils#completes#complete_staged_files('', '', [0, 0], a:options),
        \ gita#utils#completes#complete_unstaged_files('', '', [0, 0], a:options),
        \ gita#utils#completes#complete_conflicted_files('', '', [0, 0], a:options),
        \ a:candidates,
        \])
  return candidates
endfunction " }}}
function! s:ensure_commit_option(options) abort " {{{
  if !has_key(a:options, 'commit')
    let gita = gita#get()
    call histadd('input', 'HEAD')
    call histadd('input', 'INDEX')
    call histadd('input', get(gita.meta, 'commit', 'INDEX'))
    let commit = gita#utils#prompt#ask(
          \ 'Which commit do you want to compare with? (e.g INDEX, HEAD, master, master.., master..., etc.) ',
          \)
    if empty(commit)
      call gita#utils#prompt#warn(
            \ 'Operation has canceled by user',
            \)
      return -1
    endif
    let a:options.commit = commit
  endif
  return 0
endfunction " }}}
function! s:construct_commit(options) abort " {{{
  let gita = gita#get()
  let commit1_display = ''
  let commit2_display = ''
  if a:options.commit =~# '\v^.*\.\.\..*$'
    " find a common ancestor
    let [lhs, rhs] = matchlist(a:options.commit, '\v^(.*)\.\.\.(.*)$')[1 : 2]
    let lhs = empty(lhs) ? 'HEAD' : lhs
    let rhs = empty(rhs) ? 'HEAD' : rhs
    let result = gita.operations.merge_base({
          \ '--': [lhs, rhs],
          \}, {
          \ 'echo': 'fail',
          \})
    if result.status != 0
      return
    endif
    let commit1 = result.stdout
    let commit2 = empty(rhs) ? 'HEAD' : rhs
    let result = gita.operations.rev_parse({
          \ 'short': 1,
          \ 'args': result.stdout,
          \}, {
          \ 'echo': 'fail',
          \})
    if result.status == 0
      " use user-friendly name
      let commit1_display = printf('ANCESTOR:%s', result.stdout)
    endif
  elseif a:options.commit =~# '\v^.*\.\..*$'
    let [lhs, rhs] = matchlist(a:options.commit, '\v^(.*)\.\.(.*)$')[1 : 2]
    let commit1 = empty(lhs) ? 'HEAD' : lhs
    let commit2 = empty(rhs) ? 'HEAD' : rhs
  else
    let commit1 = 'WORKTREE'
    let commit2 = a:options.commit
  endif
  let commit1_display = empty(commit1_display) ? commit1 : commit1_display
  let commit2_display = empty(commit2_display) ? commit2 : commit2_display
  return {
        \ 'commit1': commit1,
        \ 'commit2': commit2,
        \ 'commit1_display': commit1_display,
        \ 'commit2_display': commit2_display,
        \}
endfunction " }}}


function! s:diff1(...) abort " {{{
  let gita = gita#get()
  let options = get(a:000, 0, {})
  if gita.fail_on_disabled()
    return
  endif
  " automatically translate 'file' option to '--'
  if has_key(options, 'file')
    let options['--'] = [options.file]
    unlet options.file
  endif
  let options.no_prefix = 1
  let options.no_color = 1
  let options.unified = '0'
  let options.histogram = 1
  let result = gita#features#diff#exec_cached(options, {
        \ 'echo': 'fail',
        \})
  if result.status != 0
    return
  endif

  if len(get(options, '--', [])) == 1
    let abspath = gita#utils#ensure_abspath(
          \ gita#utils#expand(options['--'][0]),
          \)
    let relpath = gita#utils#ensure_relpath(abspath)
    let DIFF_bufname = gita#utils#buffer#bufname(
          \ options.commit,
          \ printf('%s.diff', relpath),
          \)
  else
    let abspath = ''
    let DIFF_bufname = gita#utils#buffer#bufname(
          \ options.commit,
          \ 'diff',
          \)
  endif
  call gita#utils#buffer#open(DIFF_bufname, '', {
        \ 'opener': get(options, 'opener', 'edit'),
        \})
  call gita#utils#buffer#update(split(result.stdout, '\v\r?\n'))
  setlocal buftype=nofile bufhidden=hide noswapfile
  setlocal nomodifiable readonly
  setlocal filetype=diff

  if !empty(abspath)
    call gita#meta#set('filename', abspath)
  endif
  call gita#meta#set('commit', options.commit)
endfunction " }}}
function! s:diff2(...) abort " {{{
  let options = get(a:000, 0, {})
  " automatically assign the current buffer if no 'file' is specified
  if empty(get(options, 'file', ''))
    let options.file = '%'
  endif
  let abspath = gita#utils#ensure_abspath(
        \ gita#utils#expand(options.file)
        \)
  let relpath = gita#utils#ensure_relpath(abspath)

  " find commit1 and commit2
  let [commit1, commit2] = gita#features#diff#split_commit(options.commit)

  " commit1
  let result = gita#features#file#exec({
        \ 'commit': commit1,
        \ 'file': abspath,
        \}, {
        \ 'echo': '',
        \})
  if result.status == 0
    let COMMIT1 = split(result.stdout, '\v\r?\n')
  else
    " if the file is removed in commit, the status would be non 0 but
    " it is better to show an empty buffer thus just specify an empty list
    let COMMIT1 = []
  endif
  if commit1 ==# 'WORKTREE'
    let COMMIT1_bufname = relpath
  else
    let COMMIT1_bufname = gita#utils#buffer#bufname(
          \ commit1,
          \ relpath,
          \)
  endif

  " commit2
  let result = gita#features#file#exec({
        \ 'commit': commit2,
        \ 'file': abspath,
        \}, {
        \ 'echo': '',
        \})
  if result.status == 0
    let COMMIT2 = split(result.stdout, '\v\r?\n')
  else
    " if the file is removed in commit, the status would be non 0 but
    " it is better to show an empty buffer thus just specify an empty list
    let COMMIT2 = []
  endif
  if commit2 ==# 'WORKTREE'
    let COMMIT2_bufname = relpath
  else
    let COMMIT2_bufname = gita#utils#buffer#bufname(
          \ commit2,
          \ relpath,
          \)
  endif

  let bufnums = gita#utils#buffer#open2(
        \ COMMIT1_bufname, COMMIT2_bufname, 'vim_gita_diff', {
        \   'opener': get(options, 'opener', 'edit'),
        \   'opener2': get(options, 'opener2', 'split'),
        \   'vertical': get(options, 'vertical', 0),
        \})
  let COMMIT1_bufnum = bufnums.bufnum1
  let COMMIT2_bufnum = bufnums.bufnum2

  " COMMIT1
  execute printf('%swincmd w', bufwinnr(COMMIT1_bufnum))
  if commit1 !=# 'WORKTREE'
    call gita#utils#buffer#update(COMMIT1)
    setlocal buftype=nofile bufhidden=hide noswapfile
    setlocal nomodifiable readonly
    call gita#meta#set('filename', abspath)
  endif
  call gita#meta#set('commit', commit1)
  diffthis

  " COMMIT2
  execute printf('%swincmd w', bufwinnr(COMMIT2_bufnum))
  if commit2 !=# 'WORKTREE'
    call gita#utils#buffer#update(COMMIT2)
    setlocal buftype=nofile bufhidden=hide noswapfile
    setlocal nomodifiable readonly
    call gita#meta#set('filename', abspath)
  endif
  call gita#meta#set('commit', commit2)
  diffthis
  diffupdate
endfunction " }}}

function! gita#features#diff#split_commit(commit, ...) abort " {{{
  let options = get(a:000, 0, {})
  if a:commit =~# '\v^[^.]*\.\.\.[^.]*$'
    let rhs = matchlist(
          \ a:commit,
          \ '\v^([^.]*)\.\.\.([^.]*)$',
          \)[2]
    return [ a:commit, empty(rhs) ? 'HEAD' : rhs ]
  elseif a:commit =~# '\v^[^.]*\.\.[^.]*$'
    let [lhs, rhs] = matchlist(
          \ a:commit,
          \ '\v^([^.]*)\.\.([^.]*)$',
          \)[ 1 : 2 ]
    return [ empty(lhs) ? 'HEAD' : lhs, empty(rhs) ? 'HEAD' : rhs ]
  else
    return [ get(options, 'cached') ? 'INDEX' : 'WORKTREE', a:commit ]
  endif
endfunction " }}}
function! gita#features#diff#exec(...) abort " {{{
  let gita = gita#get()
  let options = deepcopy(get(a:000, 0, {}))
  let config = get(a:000, 1, {})
  if gita.fail_on_disabled()
    return { 'status': -1 }
  endif
  if !empty(get(options, '--', []))
    " git store files with UNIX type path separation (/)
    let options['--'] = gita#utils#ensure_unixpathlist(options['--'])
  endif
  if has_key(options, 'commit')
    let options.commit = substitute(
          \ options.commit,
          \ '\v\C\W?INDEX\W?',
          \ '', 'g')
  endif
  let options = s:D.pick(options, [
        \ '--',
        \ 'ignore_submodules',
        \ 'no_prefix',
        \ 'no_color',
        \ 'unified',
        \ 'histogram',
        \ 'cached',
        \ 'commit',
        \ 'name_status',
        \ 'stat',
        \ 'numstat',
        \])
  return gita.operations.diff(options, config)
endfunction " }}}
function! gita#features#diff#exec_cached(...) abort " {{{
  let gita = gita#get()
  let options = get(a:000, 0, {})
  let config = get(a:000, 1, {})
  if gita.fail_on_disabled()
    return { 'status': -1 }
  endif
  let cache_name = s:P.join('diff', string(s:D.pick(options, [
        \ '--',
        \ 'ignore_submodules',
        \ 'no_prefix',
        \ 'no_color',
        \ 'unified',
        \ 'histogram',
        \ 'cached',
        \ 'commit',
        \ 'name_status',
        \ 'stat',
        \ 'numstat',
        \])))
  let cached_status = gita.git.is_updated('index', 'diff') || get(config, 'force_update', 0)
        \ ? {}
        \ : gita.git.cache.repository.get(cache_name, {})
  if !empty(cached_status)
    return cached_status
  endif
  let result = gita#features#diff#exec(options, config)
  if result.status != get(config, 'success_status', 0)
    return result
  endif
  call gita.git.cache.repository.set(cache_name, result)
  return result
endfunction " }}}
function! gita#features#diff#show(...) abort " {{{
  let options = get(a:000, 0, {})
  let config = get(a:000, 1, {})
  if s:ensure_commit_option(options)
    return
  endif
  if get(options, 'window', '') ==# 'double'
    call s:diff2(options, config)
  else
    call s:diff1(options, config)
  endif
endfunction " }}}
function! gita#features#diff#command(bang, range, ...) abort " {{{
  let options = s:parser.parse(a:bang, a:range, get(a:000, 0, ''))
  if !empty(options)
    let options = extend(
          \ deepcopy(g:gita#features#diff#default_options),
          \ options)
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
