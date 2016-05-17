let s:V = gita#vital()
let s:ArgumentParser = s:V.import('ArgumentParser')

function! s:get_parser() abort
  if !exists('s:parser') || g:gita#develop
    let s:parser = s:ArgumentParser.new({
          \ 'name': 'Gita merge',
          \ 'description': 'Join two or more development histories together',
          \ 'complete_threshold': g:gita#complete_threshold,
          \ 'unknown_description': '<commits>...',
          \ 'complete_unknown': function('gita#util#complete#commit'),
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
          \ '--ff-only',
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

function! s:args_from_options(git, options) abort
  let args = gita#process#args_from_options(a:options, {
        \ 'stat': 1,
        \ 'no-stat': 1,
        \ 'log': 1,
        \ 'no-log': 1,
        \ 'squash': 1,
        \ 'no-squash': 1,
        \ 'commit': 1,
        \ 'no-commit': 1,
        \ 'ff': 1,
        \ 'no-ff': 1,
        \ 'ff-only': 1,
        \ 'rerere-autoupdate': 1,
        \ 'no-rerere-autoupdate': 1,
        \ 'verify-signatures': 1,
        \ 'no-verify-signatures': 1,
        \ 'strategy': 1,
        \ 'strategy-option': 1,
        \ 'abort': 1,
        \ 'gpg-sign': 1,
        \})
  let args = ['merge', '--no-edit', '--verbose'] + args + map(
        \ get(a:options, '__unknown__', []),
        \ 'gita#normalize#commit(a:git, v:val)'
        \)
  return filter(args, '!empty(v:val)')
endfunction

function! gita#command#merge#execute(git, options) abort
  let args = s:args_from_options(a:git, a:options)
  let result = gita#process#execute(a:git, args)
  return result
endfunction

function! gita#command#merge#command(bang, range, args) abort
  let parser  = s:get_parser()
  let options = parser.parse(a:bang, a:range, a:args)
  if empty(options)
    return {}
  endif
  let options = extend(
        \ copy(g:gita#command#merge#default_options),
        \ options
        \)
  let git = gita#core#get_or_fail()
  let result = gita#command#merge#execute(git, options)
  call gita#trigger_modified()
  return result
endfunction

function! gita#command#merge#complete(arglead, cmdline, cursorpos) abort
  let parser = s:get_parser()
  return parser.complete(a:arglead, a:cmdline, a:cursorpos)
endfunction

call gita#define_variables('command#merge', {
      \ 'default_options': {},
      \})
