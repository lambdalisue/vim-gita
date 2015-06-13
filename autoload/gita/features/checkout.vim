let s:save_cpo = &cpo
set cpo&vim


let s:D = gita#utils#import('Data.Dict')
let s:A = gita#utils#import('ArgumentParser')


" Private
function! s:get_parser() abort " {{{
  if exists('s:parser') && !get(g:, 'gita#debug', 0)
    return s:parser
  endif
  let s:parser = s:A.new({
        \ 'name': 'Gita checkout',
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
        \   'kind': s:A.kinds.value,
        \   'conflicts': ['B', 'orphan'],
        \})
  call s:parser.add_argument(
        \ '-B', [
        \   'Create a new branch with a specified name and start it at <start_point>.',
        \   'If it already exists, then reset it to <start_point>.',
        \ ], {
        \   'kind': s:A.kinds.value,
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
        \   'kind': s:A.kinds.value,
        \   'conflicts': ['b', 'B'],
        \})
  call s:parser.add_argument(
        \ 'commit', [
        \   '<branch> to checkout or <start_point> of a new branch or <tree-ish> to checkout from.',
        \])

  " A hook function to display unstaged/untracked files in completions
  function! s:parser.hooks.post_complete_optional_argument(candidates, opts) abort
    let gita = s:get_gita()
    let statuses = gita.get_parsed_status()
    let candidates = deepcopy(extend(
          \ get(statuses, 'unstaged', []),
          \ get(statuses, 'untracked', []),
          \))
    let candidates = filter(
          \ map(candidates, 'get(v:val, ''path'', '''')'),
          \ 'len(v:val) && index(a:opts.__unknown__, v:val) == -1',
          \)
    let candidates = extend(
          \ a:candidates,
          \ candidates,
          \)
    return candidates
  endfunction
  return s:parser
endfunction " }}}


function! gita#features#checkout#exec(...) abort " {{{
  let gita = gita#core#get()
  let options = get(a:000, 0, {})
  let config = get(a:000, 1, {})
  " automatically specify the current buffer if nothing is specified
  " and the buffer is a file buffer
  if empty(&buftype) && empty(get(options, '--', []))
    let options['--'] = ['%']
  endif
  if !gita.enabled
    redraw
    call gita#utils#warn(
          \ 'Gita is not available in the current buffer.',
          \)
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
function! gita#features#checkout#action(statuses, options) abort " {{{
  if empty(a:statuses)
    return
  endif
  let options = extend({
        \ '--': map(deepcopy(a:statuses), 'v:val.path'),
        \}, a:options)
  call gita#features#checkout#exec(options, {
        \ 'echo': 'both',
        \})
endfunction " }}}
function! gita#features#checkout#command(bang, range, ...) abort " {{{
  let parser = s:get_parser()
  let options = parser.parse(a:bang, a:range, get(a:000, 0, ''))
  if !empty(options)
    let result = gita#features#checkout#exec(extend({
          \ '--': get(options, '__unknown__', []),
          \}, options))
    if len(result.stdout)
      call gita#utils#infomsg(result.stdout)
    endif
  endif
endfunction " }}}
function! gita#features#checkout#complete(arglead, cmdline, cursorpos) abort " {{{
  let parser = s:get_parser()
  let candidates = parser.complete(a:arglead, a:cmdline, a:cursorpos)
  return candidates
endfunction " }}}


let &cpo = s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
