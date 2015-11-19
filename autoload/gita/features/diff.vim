let s:save_cpoptions = &cpoptions
set cpoptions&vim


let s:L = gita#import('Data.List')
let s:D = gita#import('Data.Dict')
let s:P = gita#import('System.Filepath')
let s:A = gita#import('ArgumentParser')

let s:parser = s:A.new({
      \ 'name': 'Gita[!] diff',
      \ 'description': 'Show changes between commits, commit and working tree, etc',
      \ 'description_unknown': '[{file1}, {file2}, ...]',
      \})
call s:parser.add_argument(
      \ 'commit', [
      \   'A commit which you want to compare with.',
      \   'If nothing is specified, it will ask which commit you want to compare.',
      \   'If <commit> is specified, it show changes in working tree relative to the named <commit>.',
      \   'If <commit>..<commit> is specified, it show the changes between two arbitrary <commit>.',
      \   'If <commit>...<commit> is specified, it show thechanges on the branch containing and up ',
      \   'to the second <commit>, starting at a common ancestor of both <commit>.',
      \ ], {
      \   'complete': function('gita#features#diff#_complete_commit'),
      \ })
call s:parser.add_argument(
      \ '--cached',
      \ 'Compare the changes you staged for the next commit relative to the named <commit> or HEAD', {
      \ })
call s:parser.add_argument(
      \ '--unified', '-u',
      \ 'Generate diffs with <n> lines of context instead of usual three.', {
      \ })
call s:parser.add_argument(
      \ '--minimal',
      \ 'Spend extra time to make sure the smallest possible diff is produced.', {
      \   'conflicts': ['patience', 'histogram', 'diff_algorithm'],
      \ })
call s:parser.add_argument(
      \ '--patience',
      \ 'Generate a diff using the "histogram diff" algorithm.', {
      \   'conflicts': ['minimal', 'histogram', 'diff_algorithm'],
      \ })
call s:parser.add_argument(
      \ '--histogram',
      \ 'Generate a diff using the "histogram diff" algorithm.', {
      \   'conflicts': ['minimal', 'patience', 'diff_algorithm'],
      \ })
call s:parser.add_argument(
      \ '--diff-algorithm', [
      \   'Chose a diff algorithm. The variants are as follows:',
      \   'default, myers',
      \   '  The basic greedy diff algorithm. Currently, this is the default.',
      \   'minimal',
      \   '  Spend extra time to make sure the smallest possible diff is produced.',
      \   'patience',
      \   '  Use "patience diff" algorithm when generating pathces.',
      \   'histogram',
      \   '  Extend the patience algorithm to "support low-occurrence common elements".',
      \ ], {
      \   'conflicts': ['minimal', 'patience', 'histogram'],
      \ })
call s:parser.add_argument(
      \ '--ignore-submodules',
      \ 'ignore changes to submodules, optional when: all, dirty, untracked (Default: all)', {
      \   'choices': ['all', 'dirty', 'untracked'],
      \   'on_default': 'all',
      \ })
call s:parser.add_argument(
      \ '--opener', [
      \   'A way to open a new 1st buffer such as "edit", "split", or etc.',
      \ ], {
      \   'type': s:A.types.value,
      \ },
      \)
call s:parser.add_argument(
      \ '--split', '-s', [
      \   'Open a two buffer to compare the difference.',
      \   'If it is not specified, a unified diff file will be shown.',
      \ ], {
      \   'deniable': 1,
      \ })
call s:parser.add_argument(
      \ '--opener2', [
      \   'A way to open a new 2nd buffer such as "edit", "split", or etc.',
      \   'It is a subordinate argument of --split/-s.',
      \ ], {
      \   'type': s:A.types.value,
      \   'superordinates': ['split'],
      \ },
      \)
call s:parser.add_argument(
      \ '--vertical', [
      \   'Vertically open a new 2nd buffer (vsplit).',
      \   'It is a subordinate argument of --split/-s.',
      \   'It conflict with an argument --horizontal.',
      \ ], {
      \   'conflicts': ['horizontal'],
      \   'superordinates': ['split'],
      \})
call s:parser.add_argument(
      \ '--horizontal', [
      \   'Horizontally open a new 2nd buffer (split).',
      \   'It is a subordinate argument of --split/-s.',
      \   'It conflict with an argument --vertical.',
      \ ], {
      \   'conflicts': ['vertical'],
      \   'superordinates': ['split'],
      \})
call s:parser.add_argument(
      \ '--line', [
      \   'A line number of the file to move the cursor.',
      \ ], {
      \   'type': s:A.types.value,
      \   'pattern': '\d\+',
      \   'superordinates': ['split'],
      \ }
      \)
call s:parser.add_argument(
      \ '--column', [
      \   'A column number of the file to move the cursor.',
      \ ], {
      \   'type': s:A.types.value,
      \   'pattern': '\d\+',
      \   'superordinates': ['split'],
      \ }
      \)
function! s:parser.complete_unknown(arglead, cmdline, cursorpos, options) abort " {{{
  let candidates = s:L.flatten([
        \ s:A.complete_files(a:arglead, a:cmdline, a:cursorpos, a:options),
        \ gita#utils#completes#complete_staged_files(a:arglead, a:cmdline, a:cursorpos, a:options),
        \ gita#utils#completes#complete_unstaged_files(a:arglead, a:cmdline, a:cursorpos, a:options),
        \ gita#utils#completes#complete_conflicted_files(a:arglead, a:cmdline, a:cursorpos, a:options),
        \])
  return candidates
endfunction " }}}
function! s:parser.hooks.post_validate(options) abort " {{{
  if get(a:options, 'horizontal')
    let a:options.vertical = 0
    unlet a:options.horizontal
  endif
endfunction " }}}

function! s:ensure_commit_option(options) abort " {{{
  if empty(get(a:options, 'commit'))
    call histadd('input', 'origin/HEAD...')
    call histadd('input', 'origin/HEAD')
    call histadd('input', 'HEAD')
    call histadd('input', 'INDEX')
    call histadd('input', gita#meta#get('commit', 'INDEX'))
    let commit = gita#utils#prompt#ask(
          \ 'Which commit do you want to compare with? ',
          \ substitute(gita#meta#get('commit'), '^WORKTREE$', 'INDEX', ''),
          \ 'customlist,gita#features#file#_complete_commit',
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

function! s:diff1(...) abort " {{{
  let gita = gita#get()
  let options = get(a:000, 0, {})
  if gita.fail_on_disabled()
    return
  endif
  let options['no-color'] = 1
  if s:ensure_commit_option(options)
    return
  endif
  let result = gita#features#diff#exec_cached(options, {
        \ 'echo': 'fail',
        \})
  if result.status != 0
    return
  endif

  if len(get(options, '--', [])) == 1
    let abspath = gita#utils#path#unix_abspath(
          \ gita#utils#path#expand(options['--'][0]),
          \)
    let DIFF_bufname = gita#utils#buffer#bufname(
          \ options.commit,
          \ printf('%s.diff', gita#utils#path#unix_relpath(abspath)),
          \)
  else
    let abspath = ''
    let DIFF_bufname = gita#utils#buffer#bufname(
          \ options.commit,
          \ 'diff',
          \)
  endif
  call gita#utils#buffer#open(DIFF_bufname, {
        \ 'opener': get(options, 'opener', 'edit'),
        \})
  call gita#utils#buffer#update(split(result.stdout, '\v\r?\n'))
  setlocal buftype=nofile noswapfile
  setlocal nomodifiable readonly
  setlocal filetype=diff

  if !empty(abspath)
    call gita#meta#set('filename', abspath)
  endif
  call gita#meta#set('commit', options.commit)
endfunction " }}}
function! s:diff2(...) abort " {{{
  let options = get(a:000, 0, {})

  " validate '--'
  if empty(get(options, '--', []))
    if !filereadable(expand('%')) && empty(gita#meta#get('filename'))
      call gita#utils#prompt#warn(
            \ 'Gita diff --split require a target file. ',
            \ 'To see the diff of the git repository, use --no-split option.',
            \)
      return
    endif
    let options['--'] = ['%']
  elseif len(get(options, '--', [])) > 1
    call gita#utils#prompt#error(
          \ '"split" mode in gita#features#diff#show require exact one file',
          \ 'in "--" argument of options.',
          \)
    return
  endif
  if s:ensure_commit_option(options)
    return
  endif

  let abspath = gita#utils#path#unix_abspath(
        \ gita#utils#path#expand(options['--'][0]),
        \)
  let relpath = gita#utils#path#unix_relpath(abspath)

  " find commit1 and commit2
  let [commit1, commit2] = gita#features#diff#split_commit(options.commit)

  " commit1
  let result = gita#features#file#exec_cached({
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
    call gita#utils#prompt#debug(
          \ result.args,
          \ result.stdout,
          \)
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
  let result = gita#features#file#exec_cached({
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
    call gita#utils#prompt#debug(
          \ result.args,
          \ result.stdout,
          \)
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

  " COMMIT1
  call gita#utils#buffer#open(COMMIT1_bufname, {
        \ 'group': 'diff_lhs',
        \ 'range': get(options, 'range', 'tabpage'),
        \ 'opener': get(options, 'opener', 'edit'),
        \})
  if commit1 !=# 'WORKTREE'
    call gita#utils#buffer#update(COMMIT1)
    setlocal buftype=nofile noswapfile
    setlocal nomodifiable readonly
    call gita#meta#set('filename', abspath)
    call gita#meta#set('commit', commit1)
  endif
  diffthis

  " COMMIT2
  call gita#utils#buffer#open(COMMIT2_bufname, {
        \ 'group': 'diff_rhs',
        \ 'range': get(options, 'range', 'tabpage'),
        \ 'opener': printf('%s%s',
        \   get(options, 'vertical') ? 'vertical ' : '',
        \   get(options, 'opener2', 'split'),
        \ ),
        \})
  if commit2 !=# 'WORKTREE'
    call gita#utils#buffer#update(COMMIT2)
    setlocal buftype=nofile noswapfile
    setlocal nomodifiable readonly
    call gita#meta#set('filename', abspath)
    call gita#meta#set('commit', commit2)
  endif
  diffthis
  diffupdate

  " focus COMMIT1
  keepjumps wincmd p
  " move the cursor onto
  let line_start = gita#utils#eget(options, 'line_start', line('.'))
  keepjumps call setpos('.', [0, line_start, 0, 0])
  keepjumps normal z.
  diffupdate
  syncbind
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

  " validate option
  if g:gita#develop
    call gita#utils#validate#require(options, 'commit', 'options')
    call gita#utils#validate#empty(options.commit, 'options.commit')
    call gita#utils#validate#pattern(options.commit, '\v^[^ ]+', 'options.commit')
  endif

  if !empty(get(options, '--', []))
    " git store files with UNIX type path separation (/)
    let options['--'] = gita#utils#path#unix_abspath(options['--'])
  endif
  if has_key(options, 'commit')
    let options.commit = substitute(
          \ options.commit,
          \ '\v\C\W?INDEX\W?',
          \ '', 'g')
  endif
  let options = s:D.pick(options, [
        \ '--',
        \ 'ignore-submodules',
        \ 'no-prefix',
        \ 'no-color',
        \ 'unified',
        \ 'minimal',
        \ 'patience',
        \ 'histogram',
        \ 'diff-algorithm',
        \ 'cached',
        \ 'commit',
        \ 'name-status',
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
        \ 'ignore-submodules',
        \ 'no-prefix',
        \ 'no-color',
        \ 'unified',
        \ 'histogram',
        \ 'cached',
        \ 'commit',
        \ 'name-status',
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
  if !get(options, 'split', 1)
    call s:diff1(options, config)
  else
    call s:diff2(options, config)
  endif
endfunction " }}}
function! gita#features#diff#command(bang, range, ...) abort " {{{
  let options = s:parser.parse(a:bang, a:range, get(a:000, 0, ''))
  if !empty(options)
    let options = extend(
          \ deepcopy(g:gita#features#diff#default_options),
          \ options)
    if !empty(options.__unknown__)
      let options['--'] = options.__unknown__
    endif
    call gita#action#exec('diff', options.__range__, options)
  endif
endfunction " }}}
function! gita#features#diff#complete(arglead, cmdline, cursorpos) abort " {{{
  return s:parser.complete(a:arglead, a:cmdline, a:cursorpos)
endfunction " }}}
function! gita#features#diff#_complete_commit(arglead, cmdline, cursorpos, ...) abort " {{{
  let leading = matchstr(a:arglead, '^.*\.\.\.\?')
  let arglead = substitute(a:arglead, '^.*\.\.\.\?', '', '')
  let candidates = call('gita#utils#completes#complete_branch', extend(
        \ [arglead, a:cmdline, a:cursorpos],
        \ a:000,
        \))
  let candidates = map(candidates, 'leading . v:val')
  return candidates
endfunction " }}}
function! gita#features#diff#action(candidates, options, config) abort " {{{
  let candidate = get(a:candidates, 0, {})
  if empty(candidate)
    return
  endif
  call gita#utils#anchor#focus()
  call gita#features#diff#show({
        \ '--': [gita#utils#sget([a:options, candidate], 'path')],
        \ 'commit': gita#utils#sget([a:options, candidate], 'commit'),
        \ 'line_start': gita#utils#sget([a:options, candidate], 'line_start'),
        \ 'line_end': gita#utils#sget([a:options, candidate], 'line_end'),
        \ 'split': get(a:options, 'split', 1),
        \ 'opener': get(a:options, 'opener', 'edit'),
        \ 'opener2': get(a:options, 'opener2', 'split'),
        \ 'range': get(a:options, 'range', 'tabpage'),
        \ 'vertical': get(a:options, 'vertical', 1),
        \})
endfunction " }}}

let &cpoptions = s:save_cpoptions
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
