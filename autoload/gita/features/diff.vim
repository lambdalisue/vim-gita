let s:save_cpo = &cpo
set cpo&vim


let s:L = gita#utils#import('Data.List')
let s:D = gita#utils#import('Data.Dict')
let s:P = gita#utils#import('System.Filepath')
let s:A = gita#utils#import('ArgumentParser')

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
    let commit = gita#utils#prompt#ask(
          \ 'Which commit do you want to compare with? (e.g INDEX, HEAD, master, master.., master..., etc.) ',
          \ get(gita.meta, 'commit', 'INDEX'),
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
function! s:ensure_file_option(options) abort " {{{
  if empty(get(a:options, '--', []))
    let a:options['--'] = ['%']
  elseif len(get(a:options, '--', [])) > 1
    call gita#utils#prompt#warn(
          \ 'A single file required to be specified to compare the difference.',
          \)
    return -1
  endif
  let a:options.file = gita#utils#expand(a:options['--'][0])
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

function! s:split_commit(commit, options) abort " {{{
  if a:commit =~# '\v^[^.]*\.\.\.[^.]*$'
    let rhs = matchlist(
          \ a:commit,
          \ '\v^([^.]*)\.\.\.([^.]*)$',
          \)[2]
    return [ a:commit, rhs ]
  elseif a:commit =~# '\v^[^.]*\.\.[^.]*$'
    let [lhs, rhs] = matchlist(
          \ a:commit,
          \ '\v^([^.]*)\.\.([^.]*)$',
          \)[ 1 : 2 ]
    return [ lhs, rhs ]
  else
    return [ get(a:options, 'cached') ? 'INDEX' : 'WORKTREE', a:commit ]
  endif
endfunction " }}}

function! s:diff1(...) abort " {{{
  let gita = gita#get()
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
    call gita#set_original_filename(abspath)
  endif
  call gita#set_meta({
        \ 'file': abspath,
        \ 'commit': options.commit,
        \})
endfunction " }}}
function! s:diff2(...) abort " {{{
  let gita = gita#get()
  let options = get(a:000, 0, {})
  if s:ensure_file_option(options)
    return
  endif

  let abspath = gita#utils#ensure_abspath(
        \ gita#utils#expand(options.file)
        \)
  let relpath = gita#utils#ensure_relpath(abspath)

  " find commit1 and commit2
  let result = s:construct_commit(options)
  let commit1 = result.commit1
  let commit2 = result.commit2
  let commit1_display = result.commit1_display
  let commit2_display = result.commit2_display

  " commit1
  let result = gita#features#file#exec({
        \ 'commit': commit1,
        \ 'file': options.file,
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
    let COMMIT1_bufname = options.file
  else
    let COMMIT1_bufname = gita#utils#buffer#bufname(
          \ commit1_display,
          \ relpath,
          \)
  endif

  " commit2
  let result = gita#features#file#exec({
        \ 'commit': commit2,
        \ 'file': options.file,
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
    let COMMIT2_bufname = options.file
  else
    let COMMIT2_bufname = gita#utils#buffer#bufname(
          \ commit2_display,
          \ relpath,
          \)
  endif

  let bufnums = gita#utils#buffer#open2(
        \ COMMIT1_bufname, COMMIT2_bufname, 'vim_gita_diff', {
        \   'opener': get(options, 'opener', 'edit'),
        \   'opener2': get(options, 'opener2', ''),
        \   'vertical': get(options, 'vertical', 0),
        \})
  let COMMIT1_bufnum = bufnums.bufnum1
  let COMMIT2_bufnum = bufnums.bufnum2

  " COMMIT1
  execute printf('%swincmd w', bufwinnr(COMMIT1_bufnum))
  if commit1 !=# 'WORKTREE'
    call gita#utils#buffer#update(COMMIT1)
    setlocal buftype=nofile bufhidden=hide noswapfile
    setlocal nomodifiable
    call gita#set_original_filename(abspath)
  endif
  call gita#set_meta({
        \ 'file': abspath,
        \ 'commit': commit1,
        \})
  diffthis

  " COMMIT2
  execute printf('%swincmd w', bufwinnr(COMMIT2_bufnum))
  if commit2 !=# 'WORKTREE'
    call gita#utils#buffer#update(COMMIT2)
    setlocal buftype=nofile bufhidden=hide noswapfile
    setlocal nomodifiable
    call gita#set_original_filename(abspath)
  endif
  call gita#set_meta({
        \ 'file': abspath,
        \ 'commit': commit2,
        \})
  diffthis
  diffupdate
endfunction " }}}

function! gita#features#diff#exec(...) abort " {{{
  let gita = gita#get()
  let options = deepcopy(get(a:000, 0, {}))
  let config = get(a:000, 1, {})
  if gita.fail_on_disabled()
    return { 'status': -1 }
  endif
  if !empty(get(options, '--', []))
    let options['--'] = gita#utils#ensure_pathlist(options['--'])
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
        \ 'cached',
        \ 'commit',
        \ 'name_status',
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
        \ 'cached', 'commit',
        \ 'name_status',
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
  if type(options.window) ==# type(0)
    if options.window
      call s:diff1(options, config)
    else
      call gita#features#diff#exec(options, config)
    endif
  else
    if options.window ==# 'single'
      call s:diff1(options, config)
    else
      call s:diff2(options, config)
    endif
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
