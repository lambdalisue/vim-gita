let s:save_cpo = &cpo
set cpo&vim


let s:D = gita#utils#import('Data.Dict')
let s:A = gita#utils#import('ArgumentParser')


let s:parser = s:A.new({
      \ 'name': 'Gita[!] checkout',
      \ 'description': 'Checkout a branch or paths to the working tree',
      \})
call s:parser.add_argument(
      \ '--quiet', '-q',
      \ 'Quiet, suppress feedback messages.',
      \)
call s:parser.add_argument(
      \ '--force', '-f', [
      \   'When switching branches, proceed even if the index or the working tree differs from HEAD. This is used to throw away local changes.',
      \   'When checking out paths from the index, do not fail upon unmerged entries; instead, unmerged entries are ignored.',
      \])
call s:parser.add_argument(
      \ '--ours', [
      \   'When checking out paths from the index, check out stage #2 from unmerged path.',
      \ ]
      \,{
      \   'conflicts': ['theirs'],
      \})
call s:parser.add_argument(
      \ '--theirs', [
      \   'When checking out paths from the index, check out stage #3 from unmerged path.',
      \ ]
      \,{
      \   'conflicts': ['ours'],
      \})
call s:parser.add_argument(
      \ '-b', [
      \   'Create a new branch with a specified name and start it at <start_point>.',
      \ ], {
      \   'type': s:A.types.value,
      \   'conflicts': ['B', 'orphan'],
      \})
call s:parser.add_argument(
      \ '-B', [
      \   'Create a new branch with a specified name and start it at <start_point>.',
      \   'If it already exists, then reset it to <start_point>.',
      \ ], {
      \   'type': s:A.types.value,
      \   'conflicts': ['b', 'orphan'],
      \})
call s:parser.add_argument(
      \ '--track', '-t', [
      \   'When creating a new branch set up "upstream" configuration.',
      \ ], {
      \   'conflicts': ['--no-track'],
      \})
call s:parser.add_argument(
      \ '--no-track', [
      \   'Do not set up "upstream" configuration, even if the branch.autosetupmerge configuration variable is true.',
      \ ], {
      \   'conflicts': ['--track'],
      \})
call s:parser.add_argument(
      \ '-l', [
      \   'Create the new branch''s reflog.',
      \])
call s:parser.add_argument(
      \ '--detach', [
      \   'Rather than checking out a branch to work on it, check out a commit for inspection and discardable experiments.',
      \   'This is the default behavior of "git checkout <commit>" when <commit> is not a branch name.',
      \])
call s:parser.add_argument(
      \ '--orphan', [
      \   'Create a new orphan branch, started from <start_point> and switch to it. The first commit made on this new branch will have no parents',
      \   'and it will be the root of a new history totally disconnected from all the other branches and commits.',
      \ ], {
      \   'type': s:A.types.value,
      \   'conflicts': ['b', 'B'],
      \})
call s:parser.add_argument(
      \ 'commit', [
      \   '<branch> to checkout or <start_point> of a new branch or <tree-ish> to checkout from.',
      \ ], {
      \   'complete': function('gita#completes#complete_remote_branch'),
      \ })
function! s:parser.hooks.post_complete_optional_argument(candidates, options) abort " {{{
  let candidates = extend(
        \ gita#completes#complete_staged_files('', '', [0, 0], a:options),
        \ gita#completes#complete_unstaged_files('', '', [0, 0], a:options),
        \ gita#completes#complete_conflicted_files('', '', [0, 0], a:options),
        \ a:candidates,
        \)
  return candidates
endfunction " }}}


function! gita#features#checkout#exec(...) abort " {{{
  let gita = gita#core#get()
  let options = get(a:000, 0, {})
  let config = get(a:000, 1, {})
  if gita.fail_on_disabled()
    return
  endif
  if !empty(get(options, '--', []))
    call map(options['--'], 'gita#utils#expand(v:val)')
  endif
  let options = s:D.pick(options, [
        \ '--',
        \ 'q', 'quiet',
        \ 'f', 'force',
        \ 'ours', 'theirs',
        \ 'b', 'B',
        \ 't', 'track', 'no_track',
        \ 'l',
        \ 'detach',
        \ 'orphan',
        \ 'commit',
        \])
  return gita.operations.checkout(options, config)
endfunction " }}}
function! gita#features#checkout#command(bang, range, ...) abort " {{{
  let options = s:parser.parse(a:bang, a:range, get(a:000, 0, ''))
  if !empty(options)
    let options = extend(options, {
          \ '--': options.__unknown__,
          \})
    call gita#features#checkout#exec(options)
  endif
endfunction " }}}
function! gita#features#checkout#complete(arglead, cmdline, cursorpos) abort " {{{
  return s:parser.complete(a:arglead, a:cmdline, a:cursorpos)
endfunction " }}}


let &cpo = s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
