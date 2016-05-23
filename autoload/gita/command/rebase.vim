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
          \ '--onto',
          \ 'rebase onto given branch instead of upstream', {
          \   'complete': function('gita#util#complete#commit'),
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
    call s:parser.add_argument(
          \ '--continue',
          \ 'continue', {
          \   'conflicts': ['abort', 'skip'],
          \})
    call s:parser.add_argument(
          \ '--abort',
          \ 'abort and check out the original branch', {
          \   'conflicts': ['continue', 'skip'],
          \})
    call s:parser.add_argument(
          \ '--keep-empty',
          \ 'keep the commits that do not change anything', {
          \})
    call s:parser.add_argument(
          \ '--skip',
          \ 'skip current patch and continue', {
          \   'conflicts': ['continue', 'abort'],
          \})
    call s:parser.add_argument(
          \ '--merge', '-m',
          \ 'use merging strategies to rebase', {
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
          \ '--gpg-sign', '-S',
          \ 'GPG-sign commits', {
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
          \ '--no-verify',
          \ 'this option bypasses the pre-rebase hook', {
          \})
    call s:parser.add_argument(
          \ '--verify',
          \ 'allow pre-rebase hook to run', {
          \})
    call s:parser.add_argument(
          \ '-C',
          \ 'passed to "git apply"', {
          \   'type': s:ArgumentParser.types.value,
          \})
    call s:parser.add_argument(
          \ '--force-rebase', '-f',
          \ 'force rebase even if branch is up to date', {
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
          \ '--ignore-whitespace',
          \ 'passed to "git apply"', {
          \   'conflicts': ['whitespace'],
          \})
    call s:parser.add_argument(
          \ '--whitespace',
          \ 'passed to "git apply"', {
          \   'conflicts': ['ignore-whitespace'],
          \   'type': s:ArgumentParser.types.value,
          \})
    call s:parser.add_argument(
          \ '--preserve-merges', '-p',
          \ 'try to recreate merges instead of ignoring them', {
          \})
    call s:parser.add_argument(
          \ '--exec', '-x',
          \ 'add exec lines after each commit of the editable list', {
          \   'type': s:ArgumentParser.types.value,
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
          \ '--no-ff',
          \ 'cherry-pick all commits, even if unchanged', {
          \})
  endif
  return s:parser
endfunction

function! s:args_from_options(git, options) abort
  let args = gita#process#args_from_options(a:options, {
        \ 'onto': 1,
        \ 'continue': 1,
        \ 'abort': 1,
        \ 'keep-empty': 1,
        \ 'skip': 1,
        \ 'merge': 1,
        \ 'strategy': 1,
        \ 'strategy-option': 1,
        \ 'gpg-sign': 1,
        \ 'stat': 1,
        \ 'no-stat': 1,
        \ 'no-verify': 1,
        \ 'verify': 1,
        \ 'C': 1,
        \ 'force-rebase': 1,
        \ 'fork-point': 1,
        \ 'no-fork-point': 1,
        \ 'ignore-whitespace': 1,
        \ 'whitespace': 1,
        \ 'preserve-merges': 1,
        \ 'exec': 1,
        \ 'root': 1,
        \ 'autosquash': 1,
        \ 'no-autosquash': 1,
        \ 'autostash': 1,
        \ 'no-autostash': 1,
        \ 'no-ff': 1,
        \})
  let args = ['rebase', '--verbose'] + args
  return filter(args, '!empty(v:val)')
endfunction

function! gita#command#rebase#execute(git, options) abort
  let args = s:args_from_options(a:git, a:options)
  let result = gita#process#execute(a:git, args)
  return result
endfunction

function! gita#command#rebase#command(bang, range, args) abort
  let parser  = s:get_parser()
  let options = parser.parse(a:bang, a:range, a:args)
  if empty(options)
    return {}
  endif
  let options = extend(
        \ copy(g:gita#command#rebase#default_options),
        \ options
        \)
  let git = gita#core#get_or_fail()
  let result = gita#command#rebase#execute(git, options)
  call gita#trigger_modified()
  return result
endfunction

function! gita#command#rebase#complete(arglead, cmdline, cursorpos) abort
  let parser = s:get_parser()
  return parser.complete(a:arglead, a:cmdline, a:cursorpos)
endfunction

call gita#define_variables('command#rebase', {
      \ 'default_options': {},
      \})
