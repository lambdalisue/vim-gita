let s:V = gita#vital()
let s:ArgumentParser = s:V.import('ArgumentParser')

function! s:get_parser() abort
  if !exists('s:parser') || g:gita#develop
    let s:parser = s:ArgumentParser.new({
          \ 'name': 'Gita rebase',
          \ 'description': 'Forward-port local commits to the updated upstream head',
          \ 'complete_threshold': g:gita#complete_threshold,
          \})
    call s:parser.add_argument(
          \ '--autostash',
          \ 'automatically stash/stash pop before and after', {
          \   'conflicts': ['no-autostash'],
          \})
    call s:parser.add_argument(
          \ '--no-autostash',
          \ 'do not automatically stash/stash pop before and after', {
          \   'conflicts': ['autostash'],
          \})
    call s:parser.add_argument(
          \ '--fork-point',
          \ 'use "merge-base --fork-point" to refine upstream', {
          \   'conflicts': ['no-fork-point'],
          \})
    call s:parser.add_argument(
          \ '--no-fork-point',
          \ 'do not use "merge-base --fork-point" to refine upstream', {
          \   'conflicts': ['fork-point'],
          \})
    call s:parser.add_argument(
          \ '--onto',
          \ 'rebase onto given branch instead of upstream', {
          \   'complete': function('gita#util#complete#commit'),
          \})
    call s:parser.add_argument(
          \ '--preserve-merges', '-p',
          \ 'try to recreate merges instead of ignoring them', {
          \})
    call s:parser.add_argument(
          \ '--strategy', '-s',
          \ 'rebase strategy to use', {
          \   'type': s:ArgumentParser.types.multiple,
          \})
    call s:parser.add_argument(
          \ '--strategy-option', '-X',
          \ 'option for selected rebase strategy', {
          \   'type': s:ArgumentParser.types.value,
          \})
    call s:parser.add_argument(
          \ '--no-ff',
          \ 'cherry-pick all commits, even if unchanged', {
          \})
    call s:parser.add_argument(
          \ '--merge', '-m',
          \ 'use merging strategies to rebase', {
          \})
    call s:parser.add_argument(
          \ '--exec', '-x',
          \ 'add exec lines after each commit of the editable list', {
          \   'type': s:ArgumentParser.types.value,
          \})
    call s:parser.add_argument(
          \ '--force-rebase', '-f',
          \ 'force rebase even if branch is up to date', {
          \})
    call s:parser.add_argument(
          \ '--stat',
          \ 'display a diffstat of what changed upstream', {
          \   'conflicts': ['no-stat'],
          \})
    call s:parser.add_argument(
          \ '--no-stat', '-n',
          \ 'do not show diffstat of what changed upstrem', {
          \   'conflicts': ['stat'],
          \})
    call s:parser.add_argument(
          \ '--verify',
          \ 'allow pre-rebase hook to run', {
          \})
    call s:parser.add_argument(
          \ '--rerere-autoupdate',
          \ 'allow rerere to update index with resolved conflicts', {
          \})
    call s:parser.add_argument(
          \ '--root',
          \ 'rebase all reachable commits up to the root(s)', {
          \})
    call s:parser.add_argument(
          \ '--autosquash',
          \ 'move commits that begin with squash', {
          \   'conflicts': ['no-autosquash'],
          \})
    call s:parser.add_argument(
          \ '--no-autosquash',
          \ 'do not move commits that begin with squash', {
          \   'conflicts': ['autosquash'],
          \})
    call s:parser.add_argument(
          \ '--committer-date-is-author-date',
          \ 'passed to "git am"', {
          \})
    call s:parser.add_argument(
          \ '--ignore-date',
          \ 'passed to "git am"', {
          \})
    call s:parser.add_argument(
          \ '--whitespace',
          \ 'passed to "git apply"', {
          \   'conflicts': ['ignore-whitespace'],
          \   'type': s:ArgumentParser.types.value,
          \})
    call s:parser.add_argument(
          \ '--ignore-whitespace',
          \ 'passed to "git apply"', {
          \   'conflicts': ['whitespace'],
          \})
    call s:parser.add_argument(
          \ '-C',
          \ 'passed to "git apply"', {
          \   'type': s:ArgumentParser.types.value,
          \})
    call s:parser.add_argument(
          \ '--gpg-sign', '-S',
          \ 'GPG-sign commits', {
          \})
    call s:parser.add_argument(
          \ '--continue',
          \ 'continue', {
          \})
    call s:parser.add_argument(
          \ '--abort',
          \ 'abort and check out the original branch', {
          \})
    call s:parser.add_argument(
          \ '--skip',
          \ 'skip current patch and continue', {
          \})
    call s:parser.add_argument(
          \ 'upstream',
          \ 'upstream branch to compare against', {
          \   'complete': function('gita#util#complete#branch'),
          \})
    call s:parser.add_argument(
          \ 'branch',
          \ 'working branch; defaults to HEAD', {
          \   'complete': function('gita#util#complete#branch'),
          \})
  endif
  return s:parser
endfunction

function! gita#command#rebase#command(bang, range, args) abort
  let git = gita#core#get_or_fail()
  let parser  = s:get_parser()
  let options = parser.parse(a:bang, a:range, a:args)
  if empty(options)
    return
  endif
  call gita#process#execute(git, ['rebase'] + map(
        \ options.__args__,
        \ 'gita#meta#expand(v:val)',
        \))
  call gita#util#doautocmd('User', 'GitaStatusModified')
endfunction

function! gita#command#rebase#complete(arglead, cmdline, cursorpos) abort
  let parser = s:get_parser()
  return parser.complete(a:arglead, a:cmdline, a:cursorpos)
endfunction
