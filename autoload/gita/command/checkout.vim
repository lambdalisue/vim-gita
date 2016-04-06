let s:V = gita#vital()
let s:ArgumentParser = s:V.import('ArgumentParser')

function! s:get_parser() abort
  if !exists('s:parser') || g:gita#develop
    let s:parser = s:ArgumentParser.new({
          \ 'name': 'Gita checkout',
          \ 'description': 'Switch branches or restore working tree files',
          \ 'complete_threshold': g:gita#complete_threshold,
          \ 'unknown_description': '<paths>...',
          \ 'complete_unknown': function('gita#util#complete#filename'),
          \ 'enable_positional_assign': 1,
          \})
    call s:parser.add_argument(
          \ '-b',
          \ 'create and checkout a new branch', {
          \   'conflicts': ['B', 'orphan'],
          \   'complete': function('gita#util#complete#branch'),
          \})
    call s:parser.add_argument(
          \ '-B',
          \ 'create/reset and checkout a branch', {
          \   'conflicts': ['b', 'orphan'],
          \   'complete': function('gita#util#complete#branch'),
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
          \   'complete': function('gita#util#complete#branch'),
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
          \   'complete': function('gita#util#complete#commitish'),
          \ })
  endif
  return s:parser
endfunction

function! s:args_from_options(git, options) abort
  let args = gita#process#args_from_options(a:options, {
        \ 'b': '-%k%v',
        \ 'B': '-%k%v',
        \ 'l': 1,
        \ 'detach': 1,
        \ 'track': 1,
        \ 'no-track': 1,
        \ 'orphan': '--%k %v',
        \ 'ours': 1,
        \ 'theirs': 1,
        \ 'force': 1,
        \ 'merge': 1,
        \ 'conflict': '--%k %v',
        \ 'ignore-skip-worktree-bits': 1,
        \ 'ignore-other-worktree': 1,
        \})
  let args = ['checkout'] + args + [
        \ gita#normalize#commit(a:git, get(a:options, 'commit', '')),
        \ '--',
        \] + map(
        \ get(a:options, '__unknown__', []),
        \ 'gita#normalize#relpath(a:git, v:val)'
        \)
  return filter(args, '!empty(v:val)')
endfunction

function! gita#command#checkout#command(bang, range, args) abort
  let parser  = s:get_parser()
  let options = parser.parse(a:bang, a:range, a:args)
  if empty(options)
    return
  endif
  let options = extend(
        \ copy(g:gita#command#checkout#default_options),
        \ options
        \)
  let git = gita#core#get_or_fail()
  let args = s:args_from_options(git, options)
  call gita#process#execute(git, args)
  call gita#trigger_modified()
endfunction

function! gita#command#checkout#complete(arglead, cmdline, cursorpos) abort
  let parser = s:get_parser()
  return parser.complete(a:arglead, a:cmdline, a:cursorpos)
endfunction

call gita#define_variables('command#checkout', {
      \ 'default_options': {},
      \})
