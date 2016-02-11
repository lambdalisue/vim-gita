let s:V = gita#vital()
let s:Dict = s:V.import('Data.Dict')
let s:Path = s:V.import('System.Filepath')
let s:Git = s:V.import('Git')
let s:GitProcess = s:V.import('Git.Process')
let s:ArgumentParser = s:V.import('ArgumentParser')

function! s:pick_available_options(options) abort
  " Note:
  " Let me know or send me a PR if you need options not listed below
  let options = s:Dict.pick(a:options, [
        \ 'force',
        \ 'ours', 'theirs',
        \ 'b', 'B',
        \ 'track', 'no-track',
        \ 'l',
        \ 'detach',
        \ 'orphan',
        \ 'ignore-skip-worktree-bits',
        \ 'merge',
        \ 'conflict',
        \ 'ignore-other-worktrees',
        \])
  return options
endfunction
function! s:apply_command(git, commit, filenames, options) abort
  let options = s:pick_available_options(a:options)
  let options['commit'] = a:commit
  if !empty(a:filenames)
    let options['--'] = map(
          \ copy(a:filenames),
          \ 's:Path.unixpath(s:Git.get_relative_path(a:git, v:val))',
          \)
  endif
  let result = gita#execute(a:git, 'checkout', options)
  if result.status
    call s:GitProcess.throw(result.stdout)
  elseif !get(a:options, 'quiet', 0)
    call s:Prompt.title('OK: ' . join(result.args, ' '))
    echo join(result.content, "\n")
  endif
  return result.content
endfunction

function! gita#command#checkout#call(...) abort
  let options = gita#option#init('', get(a:000, 0, {}), {
        \ 'commit': '',
        \ 'filenames': [],
        \})
  let git = gita#get_or_fail()
  let commit = gita#variable#get_valid_range(options.commit, {
        \ '_allow_empty': 1,
        \})
  if empty(options.filenames)
    let filenames = []
  else
    let filenames = map(
          \ copy(options.filenames),
          \ 'gita#variable#get_valid_filename(v:val)',
          \)
  endif
  let content = s:apply_command(git, commit, filenames, options)
  call gita#util#doautocmd('StatusModified')
  return {
        \ 'commit': commit,
        \ 'filenames': filenames,
        \ 'content': content,
        \ 'options': options,
        \}
endfunction

function! s:get_parser() abort
  if !exists('s:parser') || g:gita#develop
    let s:parser = s:ArgumentParser.new({
          \ 'name': 'Gita checkout',
          \ 'description': 'Switch branches or restore working tree files',
          \ 'complete_unknown': function('gita#variable#complete_filename'),
          \ 'unknown_description': '<paths>...',
          \ 'complete_threshold': g:gita#complete_threshold,
          \})
    call s:parser.add_argument(
          \ '--quiet', '-q',
          \ 'be quiet',
          \)
    call s:parser.add_argument(
          \ '-b',
          \ 'create and checkout a new branch', {
          \   'conflicts': ['B', 'orphan'],
          \})
    call s:parser.add_argument(
          \ '-B',
          \ 'create/reset and checkout a branch', {
          \   'conflicts': ['b', 'orphan'],
          \})
    call s:parser.add_argument(
          \ '-l',
          \ 'create reflog for new branch',
          \)
    call s:parser.add_argument(
          \ '--detach',
          \ 'detach the HEAD at named commit',
          \)
    call s:parser.add_argument(
          \ '--track', '-t',
          \ 'set upstream info for new branch',
          \)
    call s:parser.add_argument(
          \ '--no-track',
          \ 'do not set upstream even if the branch.autosetupmerge is true',
          \)
    call s:parser.add_argument(
          \ '--orphan',
          \ 'new unparented branch', {
          \   'conflicts': ['b', 'B'],
          \})
    call s:parser.add_argument(
          \ '--ours', '-2',
          \ 'checkout our version for unmerged files', {
          \   'conflicts': ['theirs'],
          \})
    call s:parser.add_argument(
          \ '--theirs', '-3',
          \ 'checkout their version for unmerged files', {
          \   'conflicts': ['ours'],
          \})
    call s:parser.add_argument(
          \ '--force', '-f',
          \ 'force checkout (throw away local modifications',
          \)
    call s:parser.add_argument(
          \ '--merge', '-m',
          \ 'perform a 3-way merge with the new branch',
          \)
    call s:parser.add_argument(
          \ '--conflict',
          \ 'conflict style (merge or diff3)', {
          \   'choices': ['merge', 'diff3'],
          \})
    call s:parser.add_argument(
          \ '--ignore-skip-worktree-bits',
          \ 'do not limit pathspecs to sparse entries only',
          \)
    call s:parser.add_argument(
          \ '--ignore-other-worktrees',
          \ 'do not check if another worktree is holding the given ref',
          \)
    call s:parser.add_argument(
          \ 'commit',
          \ '<branch> to checkout or <start_point> of a new branch or <tree-ish> to checkout from.', {
          \   'complete': function('gita#variable#complete_commit'),
          \ })
  endif
  return s:parser
endfunction
function! gita#command#checkout#command(...) abort
  let parser  = s:get_parser()
  let options = call(parser.parse, a:000, parser)
  if empty(options)
    return
  endif
  if !empty(options.__unknown__)
    let options.filenames = options.__unknown__
  endif
  " extend default options
  let options = extend(
        \ deepcopy(g:gita#command#checkout#default_options),
        \ options,
        \)
  call gita#command#checkout#call(options)
endfunction
function! gita#command#checkout#complete(...) abort
  let parser = s:get_parser()
  return call(parser.complete, a:000, parser)
endfunction

call gita#util#define_variables('command#checkout', {
      \ 'default_options': {},
      \})
