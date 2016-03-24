let s:V = gita#vital()
let s:ArgumentParser = s:V.import('ArgumentParser')

function! s:get_parser() abort
  if !exists('s:parser') || g:gita#develop
    let s:parser = s:ArgumentParser.new({
          \ 'name': 'Gita merge',
          \ 'description': 'Join two or more development histories together',
          \ 'complete_threshold': g:gita#complete_threshold,
          \ 'unknown_description': '<commits>...',
          \ 'complete_unknown': function('gita#complete#commit'),
          \})
    call s:parser.add_argument(
          \ '--stat',
          \ 'show a diffstat at the end of the merge', {
          \   'conflicts': ['no-stat'],
          \})
    call s:parser.add_argument(
          \ '--no-stat', '-n',
          \ 'do not show a diffstat at the end of the merge', {
          \   'conflicts': ['stat'],
          \})
    call s:parser.add_argument(
          \ '--log',
          \ 'add (at most {LOG}) entries from shortlog to merge commit message', {
          \   'pattern': '^\d\+$',
          \   'conflicts': ['no-log'],
          \})
    call s:parser.add_argument(
          \ '--no-log',
          \ 'do not add entries from shortlog to merge commit message', {
          \   'conflicts': ['log'],
          \})
    call s:parser.add_argument(
          \ '--squash',
          \ 'create a single commit instead of doing a merge', {
          \   'conflicts': ['no-squash'],
          \})
    call s:parser.add_argument(
          \ '--no-squash',
          \ 'do not create a single commit instead of doing a merge', {
          \   'conflicts': ['squash'],
          \})
    call s:parser.add_argument(
          \ '--commit',
          \ 'perform a commit if the merge succeeds (default)', {
          \   'conflicts': ['no-commit'],
          \})
    call s:parser.add_argument(
          \ '--no-commit',
          \ 'do not perform a commit even if the merge succeeds', {
          \   'conflicts': ['commit'],
          \})
    call s:parser.add_argument(
          \ '--ff',
          \ 'allow fast-forward (default)', {
          \   'conflicts': ['no-ff', 'ff-only'],
          \})
    call s:parser.add_argument(
          \ '--no-ff',
          \ 'create a merge commit even when the merge resolve as a fast-forward', {
          \   'conflicts': ['ff', 'ff-only'],
          \})
    call s:parser.add_argument(
          \ '--only-ff',
          \ 'abort if fast-forward is not possible', {
          \   'conflicts': ['ff', 'no-ff'],
          \})
    call s:parser.add_argument(
          \ '--rerere-autoupdate',
          \ 'update the index with reused conflict resolution if possible', {
          \   'conflicts': ['no-rerere-autoupdate'],
          \})
    call s:parser.add_argument(
          \ '--no-rerere-autoupdate',
          \ 'do not update the index with reused conflict resolution if possible', {
          \   'conflicts': ['rerere-autoupdate'],
          \})
    call s:parser.add_argument(
          \ '--verify-signatures',
          \ 'verify that the named commit has a valid GPG signature', {
          \   'conflicts': ['no-verify-signatures'],
          \})
    call s:parser.add_argument(
          \ '--no-verify-signatures',
          \ 'do not verify that the named commit has a valid GPG signature', {
          \   'conflicts': ['verify-signatures'],
          \})
    call s:parser.add_argument(
          \ '--strategy', '-s',
          \ 'merge strategy to use', {
          \   'type': s:ArgumentParser.types.multiple,
          \})
    call s:parser.add_argument(
          \ '--strategy-option', '-X',
          \ 'option for selected merge strategy', {
          \   'type': s:ArgumentParser.types.value,
          \})
    call s:parser.add_argument(
          \ '--abort',
          \ 'abort the current in-progress merge', {
          \})
    call s:parser.add_argument(
          \ '--gpg-sign', '-S',
          \ 'GPG sign commit', {
          \})
  endif
  return s:parser
endfunction

function! gita#command#merge#call(...) abort
  let options = extend({
        \ 'commits': [],
        \}, get(a:000, 0, {}))
  let git = gita#core#get_or_fail()
  let commits = map(
        \ copy(options.commits),
        \ 'gita#variable#get_valid_commit(git, v:val)',
        \)
  let content = s:execute_command(git, commits, options)
  call gita#util#doautocmd('User', 'GitaStatusModified')
  return {
        \ 'commits': commits,
        \ 'content': content,
        \ 'options': options,
        \}
endfunction

function! gita#command#merge#command(bang, range, args) abort
  let parser  = s:get_parser()
  let options = parser.parse(a:bang, a:range, a:args)
  if empty(options)
    return
  endif
  call gita#execute(['merge', '--no-edit', '--verbose'] + options.__args__)
  call gita#util#doautocmd('User', 'GitaStatusModified')
endfunction

function! gita#command#merge#complete(arglead, cmdline, cursorpos) abort
  let parser = s:get_parser()
  return parser.complete(a:arglead, a:cmdline, a:cursorpos)
endfunction

