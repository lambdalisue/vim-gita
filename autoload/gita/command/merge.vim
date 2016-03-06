let s:V = gita#vital()
let s:Dict = s:V.import('Data.Dict')
let s:Prompt = s:V.import('Vim.Prompt')
let s:GitProcess = s:V.import('Git.Process')
let s:ArgumentParser = s:V.import('ArgumentParser')

function! s:pick_available_options(options) abort
  " Note:
  " Let me know or send me a PR if you need options not listed below
  return s:Dict.pick(a:options, [
        \ 'commit', 'no-commit',
        \ 'ff', 'no-ff', 'ff-only',
        \ 'log', 'no-log',
        \ 'stat', 'no-stat',
        \ 'squash', 'no-squash',
        \ 'strategy',
        \ 'strategy-option',
        \ 'verify-signatures', 'no-verify-signatures',
        \ 'gpg-sign',
        \ 'm',
        \ 'rerere-autoupdate',
        \ 'abort',
        \])
endfunction
function! s:apply_command(git, commits, options) abort
  let options = s:pick_available_options(a:options)
  let options['verbose'] = 1
  let options['no-edit'] = 1
  if !empty(a:commits)
    let options['commit'] = a:commits
  endif
  let result = gita#execute(a:git, 'merge', options)
  if result.status
    call s:GitProcess.throw(result)
  elseif !get(a:options, 'quiet', 0)
    call s:Prompt.title('OK: ' . join(result.args, ' '))
    echo join(result.content, "\n")
  endif
  return result.content
endfunction

function! gita#command#merge#call(...) abort
  let options = extend({
        \ 'commits': [],
        \}, get(a:000, 0, {}))
  let git = gita#core#get_or_fail()
  if empty(options.commits)
    let commits = []
  else
    let commits = map(
          \ copy(options.commits),
          \ 'gita#variable#get_valid_commit(v:val)',
          \)
  endif
  let content = s:apply_command(git, commits, options)
  call gita#util#doautocmd('User', 'GitaStatusModified')
  return {
        \ 'commits': commits,
        \ 'content': content,
        \ 'options': options,
        \}
endfunction

function! s:get_parser() abort
  if !exists('s:parser') || g:gita#develop
    let s:parser = s:ArgumentParser.new({
          \ 'name': 'Gita merge',
          \ 'description': 'Join two or more development histories together',
          \ 'complete_unknown': function('gita#variable#complete_commit'),
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
function! gita#command#merge#command(...) abort
  let parser  = s:get_parser()
  let options = call(parser.parse, a:000, parser)
  if empty(options)
    return
  endif
  if !empty(options.__unknown__)
    let options.commits = options.__unknown__
  endif
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

