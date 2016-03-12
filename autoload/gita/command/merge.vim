let s:V = gita#vital()
let s:Dict = s:V.import('Data.Dict')
let s:Prompt = s:V.import('Vim.Prompt')
let s:ArgumentParser = s:V.import('ArgumentParser')

"
" TODO: Refactoring
"

function! s:execute_command(git, commits, paths, options) abort
  let args = gita#util#args_from_options(a:options, {
        \ 'commit': 1,
        \ 'no-commit': 1,
        \ 'ff': 1,
        \ 'no-ff': 1,
        \ 'ff-only': 1,
        \ 'log': 1,
        \ 'no-log': 1,
        \ 'stat': 1,
        \ 'no-stat': 1,
        \ 'squash': 1,
        \ 'no-squash': 1,
        \ 'strategy': 1,
        \ 'strategy-option': 1,
        \ 'verify-signatures': 1,
        \ 'no-verify-signatures': 1,
        \ 'gpg-sign': 1,
        \ 'm': 1,
        \ 'rerere-autoupdate': 1,
        \ 'abort': 1,
        \})
  let args = ['merge', '--no-edit', '--verbose'] + args + a:commits
  return gita#execute(a:git, args, s:Dict.pick(a:options, [
        \ 'quiet', 'fail_silently',
        \]))
endfunction

function! s:get_parser() abort
  if !exists('s:parser') || g:gita#develop
    let s:parser = s:ArgumentParser.new({
          \ 'name': 'Gita merge',
          \ 'description': 'Join two or more development histories together',
          \ 'complete_unknown': function('gita#complete#commit'),
          \ 'unknown_description': '<commits>...',
          \ 'complete_threshold': g:gita#complete_threshold,
          \})
    call s:parser.add_argument(
          \ '--quiet',
          \ 'be quiet',
          \)
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
        \ 'gita#variable#get_valid_commit(v:val)',
        \)
  let content = s:execute_command(git, commits, options)
  call gita#util#doautocmd('User', 'GitaStatusModified')
  return {
        \ 'commits': commits,
        \ 'content': content,
        \ 'options': options,
        \}
endfunction

function! gita#command#merge#command(...) abort
  let parser  = s:get_parser()
  let options = call(parser.parse, a:000, parser)
  if empty(options)
    return
  endif
  let options.commits = options.__unknown__
  " extend default options
  let options = extend(
        \ deepcopy(g:gita#command#merge#default_options),
        \ options,
        \)
  call gita#command#merge#call(options)
endfunction

function! gita#command#merge#complete(...) abort
  let parser = s:get_parser()
  return call(parser.complete, a:000, parser)
endfunction

call gita#util#define_variables('command#merge', {
      \ 'default_options': {},
      \})

