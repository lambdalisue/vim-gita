let s:V = gita#vital()
let s:Dict = s:V.import('Data.Dict')
let s:Prompt = s:V.import('Vim.Prompt')
let s:GitProcess = s:V.import('Git.Process')
let s:ArgumentParser = s:V.import('ArgumentParser')

function! s:pick_available_options(options) abort
  " Note:
  " Let me know or send me a PR if you need options not listed below
  return s:Dict.pick(a:options, [
        \ 'onto',
        \ 'upstream',
        \ 'branch',
        \ 'continue',
        \ 'abort',
        \ 'keep-empty',
        \ 'skip',
        \ 'merge',
        \ 'strategy',
        \ 'strategy-option',
        \ 'gpg-sign',
        \ 'stat', 'no-stat',
        \ 'verify', 'no-verify',
        \ 'C',
        \ 'force-rebase',
        \ 'fork-point', 'no-fork-point',
        \ 'ignore-whitespace', 'whitespace',
        \ 'committer-date-is-author-date', 'ignore-date',
        \ 'preserve-merges',
        \ 'exec',
        \ 'root',
        \ 'autosquash', 'no-autosquash',
        \ 'autostash', 'no-autostash',
        \ 'rerere-autoupdate',
        \])
endfunction
function! s:apply_command(git, options) abort
  let options = s:pick_available_options(a:options)
  let options['verbose'] = 1
  let result = gita#execute(a:git, 'rebase', options)
  if result.status
    call s:GitProcess.throw(result)
  elseif !get(a:options, 'quiet', 0)
    call s:Prompt.title('OK: ' . join(result.args, ' '))
    echo join(result.content, "\n")
  endif
  return result.content
endfunction

function! gita#command#rebase#call(...) abort
  let options = extend({
        \}, get(a:000, 0, {}))
  let git = gita#get_or_fail()
  let content = s:apply_command(git, options)
  call gita#util#doautocmd('User', 'GitaStatusModified')
  return {
        \ 'content': content,
        \ 'options': options,
        \}
endfunction

function! s:get_parser() abort
  if !exists('s:parser') || g:gita#develop
    let s:parser = s:ArgumentParser.new({
          \ 'name': 'Gita rebase',
          \ 'description': 'Forward-port local commits to the updated upstream head',
          \ 'complete_threshold': g:gita#complete_threshold,
          \})
    call s:parser.add_argument(
          \ '--quiet',
          \ 'be quiet',
          \)
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
          \   'complete': function('gita#variable#complete_commit'),
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
          \ '--no-stat', '-n'
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
          \   'complete': function('gita#variable#complete_commit'), 
          \})
    call s:parser.add_argument(
          \ 'branch',
          \ 'working branch; defaults to HEAD', {
          \   'complete': function('gita#variable#complete_commit'), 
          \})
  endif
  return s:parser
endfunction
function! gita#command#rebase#command(...) abort
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
        \ deepcopy(g:gita#command#rebase#default_options),
        \ options,
        \)
  call gita#command#rebase#call(options)
endfunction
function! gita#command#rebase#complete(...) abort
  let parser = s:get_parser()
  return call(parser.complete, a:000, parser)
endfunction

call gita#util#define_variables('command#rebase', {
      \ 'default_options': {},
      \})

