let s:save_cpoptions = &cpoptions
set cpoptions&vim


let s:D = gita#import('Data.Dict')
let s:P = gita#import('System.Filepath')
let s:A = gita#import('ArgumentParser')


" ArgumentParser {{{
let s:parser = s:A.new({
      \ 'name': 'Gita[!] file',
      \ 'description': 'Show a file content of a working tree, index, or specified commit.',
      \})
call s:parser.add_argument(
      \ 'commit', [
      \   'A Gita specialized commit-ish which you want to show. The followings are Gita special terms:',
      \   'WORKTREE             it show the content of the current working tree.',
      \   'INDEX                it show the content of the current index (staging area for next commit).',
      \   '<commit>...<commit>  it show the content of an common ancestor between <commit>.',
      \ ], {
      \   'complete': function('gita#features#file#_complete_commit'),
      \})
call s:parser.add_argument(
      \ 'file', [
      \   'A filepath which you want to see the content.',
      \   'The current buffer is used automatically when the option is omitted.',
      \ ],
      \)
call s:parser.add_argument(
      \ '--opener', [
      \   'A way to open a new buffer such as "edit", "split", or etc.',
      \ ], {
      \   'type': s:A.types.value,
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
call s:parser.add_argument(
      \ '--line', [
      \   'A line number of the file to move the cursor.',
      \ ], {
      \   'type': s:A.types.value,
      \   'pattern': '\d\+',
      \ }
      \)
call s:parser.add_argument(
      \ '--column', [
      \   'A column number of the file to move the cursor.',
      \ ], {
      \   'type': s:A.types.value,
      \   'pattern': '\d\+',
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
" }}}

function! s:ensure_file_option(options) abort " {{{
  if empty(get(a:options, 'file'))
    let filename = gita#utils#path#expand('%')
    if empty(filename)
      call gita#utils#prompt#warn(
            \ 'No file is specified and could not automatically be detected.'
            \)
      call gita#utils#prompt#echo(
            \ 'Operation has canceled.'
            \)
      return -1
    endif
    let a:options.file = '%'
  endif
  return 0
endfunction " }}}
function! s:ensure_commit_option(options) abort " {{{
  if empty(get(a:options, 'commit', ''))
    call histadd('input', 'HEAD')
    call histadd('input', 'INDEX')
    call histadd('input', 'WORKTREE')
    call histadd('input', gita#meta#get('commit', 'WORKTREE'))
    let commit = gita#utils#prompt#ask(
          \ 'Which commit do you want to show? ',
          \ gita#meta#get('commit', ''),
          \ 'customlist,gita#features#file#_complete_commit',
          \)
    if empty(commit)
      call gita#utils#prompt#echo(
            \ 'Operation has canceled by user',
            \)
      return -1
    endif
    let a:options.commit = commit
  endif

  " <commit> might be <commit>..<commit> and git show does not understand
  " thus simply use a left hand side one
  if a:options.commit =~# '\v^[^.]*\.\.[^.]*$'
    let lhs = matchlist(
          \ a:options.commit,
          \ '\v^([^.]*)\.\.([^.]*)$',
          \)[1]
    let a:options.commit = lhs
  endif
  return 0
endfunction " }}}

function! s:exec_worktree(gita, options, config) abort " {{{
  let abspath = a:options.file
  if filereadable(abspath)
    return {
          \ 'status': 0,
          \ 'stdout': join(readfile(abspath), "\n"),
          \ 'args': [],
          \}
  else
    let errormsg = printf(
          \ '%s is not readable.',
          \ gita#utils#path#unix_relpath(abspath),
          \)
    if get(a:config, 'echo', 'both') =~# '\%(both\|fail\)'
      call gita#utils#prompt#error(errormsg)
    endif
    return {
          \ 'status': -1,
          \ 'stdout': errormsg,
          \ 'args': [],
          \}
  endif
endfunction " }}}
function! s:exec_ancestor(gita, options, config) abort " {{{
  let [lhs, rhs] = matchlist(
        \ a:options.commit,
        \ '\v^([^.]*)\.\.\.([^.]*)$'
        \)[1 : 2]
  let lhs = empty(lhs) ? 'HEAD' : lhs
  let rhs = empty(rhs) ? 'HEAD' : rhs
  let result = a:gita.operations.merge_base({
        \ 'commit1': lhs,
        \ 'commit2': rhs,
        \}, {
        \ 'echo': '',
        \})
  if !result.status
    return s:exec_commit(
          \ a:gita,
          \ extend(deepcopy(a:options), { 'commit': result.stdout }),
          \ a:config,
          \)
  else
    let errormsg = printf(
          \ 'An common ancestor between "%s" and "%s" could not be found.',
          \ lhs, rhs,
          \)
    if get(a:config, 'echo', 'both') =~# '^\%(both\|fail\)$'
      call gita#utils#prompt#error(printf(
            \ 'Fail: %s', join(result.args),
            \))
      call gita#utils#prompt#echo(result.stdout)
      call gita#utils#prompt#echo(errormsg)
    endif
    return {
          \ 'status': -1,
          \ 'stdout': errormsg,
          \}
  endif
endfunction " }}}
function! s:exec_commit(gita, options, config) abort " {{{
  let abspath = a:options.file
  let commit = substitute(
        \ a:options.commit,
        \ '\v\.?\zsINDEX\ze\.?$',
        \ '', 'g',
        \)
  " Note:
  "   relpath requires to be a relative path from a repository root for 'show'
  return a:gita.operations.show({
        \ 'object': printf(
        \   '%s:%s',
        \   commit,
        \   gita#utils#path#unix_relpath(a:gita.git.get_relative_path(abspath)),
        \ ),
        \}, a:config)
endfunction " }}}

function! gita#features#file#exec(...) abort " {{{
  let gita = gita#get()
  let options = get(a:000, 0, {})
  let config = get(a:000, 1, {})
  if gita.fail_on_disabled()
    return { 'status': -1 }
  endif

  " validate option
  if g:gita#develop
    call gita#utils#validate#require(options, 'file', 'options')
    call gita#utils#validate#require(options, 'commit', 'options')
    call gita#utils#validate#empty(options.commit, 'options.commit')
    call gita#utils#validate#pattern(options.commit, '\v^[^ ]+', 'options.commit')
  endif

  " ensure absolute path
  let options.file = gita#utils#path#unix_abspath(
        \ gita#utils#path#expand(options.file),
        \)

  " select a proper function via 'commit'
  if options.commit ==# 'WORKTREE'
    return s:exec_worktree(gita, options, config)
  elseif options.commit =~# '\v^[^.]*\.\.\.[^.]*$'
    return s:exec_ancestor(gita, options, config)
  elseif options.commit =~# '\v^[^.]*\.\.[^.]*$'
    let errormsg = printf(
          \ 'A commit range (%s) could not be specified to Gita file',
          \ options.commit,
          \)
    if get(config, 'echo', 'both') =~# '^\%(both\|fail\)$'
      call gita#utils#prompt#error(errormsg)
    endif
    return { 'status': -1, 'stdout': errormsg }
  else
    return s:exec_commit(gita, options, config)
  endif
endfunction " }}}
function! gita#features#file#exec_cached(...) abort " {{{
  let gita = gita#get()
  let options = get(a:000, 0, {})
  let config = get(a:000, 1, {})
  if gita.fail_on_disabled()
    return { 'status': -1 }
  endif
  let cache_name = s:P.join('file', string(s:D.pick(options, [
        \ 'file',
        \ 'commit',
        \])))
  let cached_status =
        \ options.commit == 'WORKTREE'
        \ || gita.git.is_updated('index', 'file')
        \ || get(config, 'force_update')
        \   ? {}
        \   : gita.git.cache.repository.get(cache_name, {})
  if !empty(cached_status)
    return cached_status
  endif
  let result = gita#features#file#exec(options, config)
  if result.status != get(config, 'success_status', 0)
    return result
  endif
  call gita.git.cache.repository.set(cache_name, result)
  return result
endfunction " }}}
function! gita#features#file#show(...) abort " {{{
  let options = get(a:000, 0, {})

  " regulate options
  if s:ensure_file_option(options)   | return | endif
  if s:ensure_commit_option(options) | return | endif

  let result = gita#features#file#exec_cached(options, {
        \ 'echo': 'fail',
        \})
  if result.status
    return
  endif

  let abspath = gita#utils#path#unix_abspath(options.file)
  let relpath = gita#utils#path#unix_relpath(abspath)

  if options.commit ==# 'WORKTREE'
    let bufname = expand(relpath)
  else
    let bufname = gita#utils#buffer#bufname(
          \ options.commit,
          \ expand(relpath),
          \)
  endif
  call gita#utils#buffer#open(bufname, {
        \ 'opener': get(options, 'opener', 'edit'),
        \})

  if options.commit !=# 'WORKTREE'
    setlocal buftype=nofile noswapfile
    setlocal nomodifiable readonly
    call gita#utils#buffer#update(
          \ split(result.stdout, '\v\r?\n')
          \)
    call gita#meta#set('filename', abspath)
  endif
  call gita#meta#set('commit', options.commit)
  " move the cursor onto
  let line_start = gita#utils#eget(options, 'line_start', line('.'))
  keepjumps call setpos('.', [0, line_start, 0, 0])
  keepjumps normal z.
endfunction " }}}
function! gita#features#file#command(bang, range, ...) abort " {{{
  let options = s:parser.parse(a:bang, a:range, get(a:000, 0, ''))
  if !empty(options)
    let options = extend(
          \ deepcopy(g:gita#features#file#default_options),
          \ options,
          \)
    call gita#action#exec('open', options.__range__, options)
  endif
endfunction " }}}
function! gita#features#file#complete(arglead, cmdline, cursorpos) abort " {{{
  return s:parser.complete(a:arglead, a:cmdline, a:cursorpos)
endfunction " }}}
function! gita#features#file#_complete_commit(arglead, cmdline, cursorpos, ...) abort " {{{
  let leading = matchstr(a:arglead, '^.*\.\.\.')
  let arglead = substitute(a:arglead, '^.*\.\.\.', '', '')
  let candidates = call('gita#utils#completes#complete_branch', extend(
        \ [arglead, a:cmdline, a:cursorpos],
        \ a:000,
        \))
  let candidates = extend(['WORKTREE', 'INDEX', 'HEAD'], candidates)
  let candidates = map(candidates, 'leading . v:val')
  return filter(deepcopy(candidates), 'v:val =~# "^" . a:arglead')
endfunction " }}}
function! gita#features#file#action(candidates, options, config) abort " {{{
  let candidate = get(a:candidates, 0, {})
  if empty(candidate)
    return
  endif
  let commit = gita#utils#sget([a:options, candidate], 'commit')
  let file = gita#utils#sget([a:options, candidate], 'path')
  let file = (commit ==# 'WORKTREE')
        \ ? gita#utils#sget([a:options, candidate], 'realpath', file)
        \ : file
  call gita#utils#anchor#focus()
  call gita#features#file#show({
        \ 'file': file,
        \ 'commit': commit,
        \ 'line_start': gita#utils#sget([a:options, candidate], 'line_start'),
        \ 'line_end': gita#utils#sget([a:options, candidate], 'line_end'),
        \ 'opener': get(a:options, 'opener', 'edit'),
        \ 'range':  get(a:options, 'range', 'tabpage'),
        \})
endfunction " }}}

let &cpoptions = s:save_cpoptions
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
