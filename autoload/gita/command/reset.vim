let s:V = gita#vital()
let s:ArgumentParser = s:V.import('ArgumentParser')

function! s:get_parser() abort
  if !exists('s:parser') || g:gita#develop
    let s:parser = s:ArgumentParser.new({
          \ 'name': 'Gita reset',
          \ 'description': 'Reset current HEAD to the specified state',
          \ 'complete_threshold': g:gita#complete_threshold,
          \ 'unknown_description': '<paths>...',
          \ 'complete_unknown': function('gita#util#complete#filename'),
          \})
    call s:parser.add_argument(
          \ '--mixed',
          \ 'reset HEAD and index',
          \)
    call s:parser.add_argument(
          \ '--soft',
          \ 'reset only HEAD',
          \)
    call s:parser.add_argument(
          \ '--hard',
          \ 'reset HEAD, index and working tree',
          \)
    call s:parser.add_argument(
          \ '--merge',
          \ 'reset HEAD, index and working tree',
          \)
    call s:parser.add_argument(
          \ '--keep',
          \ 'reset HEAD but keep local changes',
          \)
    call s:parser.add_argument(
          \ 'commit', [
          \   'a commit of reset target.',
          \   'if nothing is specified, it reset a content of the index to HEAD.',
          \   'if <commit> is specified, it reset a content of the index to the named <commit>.',
          \], {
          \   'complete': function('gita#util#complete#commitish'),
          \   'superordinates': [
          \     'mixed', 'soft', 'hard', 'merge', 'keep',
          \   ],
          \})
  endif
  return s:parser
endfunction

function! s:args_from_options(git, options) abort
  let args = gita#process#args_from_options(a:options, {
        \ 'mixed': 1,
        \ 'soft': 1,
        \ 'hard': 1,
        \ 'merge': 1,
        \ 'keep': 1,
        \})
  let args = ['reset'] + args + [
        \ gita#normalize#commit(a:git, get(a:options, 'commit', '')),
        \ '--',
        \] + map(
        \ get(a:options, '__unknown__', []),
        \ 'gita#normalize#relpath(a:git, v:val)'
        \)
  return filter(args, '!empty(v:val)')
endfunction

function! gita#command#reset#command(bang, range, args) abort
  let git = gita#core#get_or_fail()
  let parser  = s:get_parser()
  let options = parser.parse(a:bang, a:range, a:args)
  if empty(options)
    return
  endif
  let options = extend(
        \ copy(g:gita#command#reset#default_options),
        \ options
        \)
  let git = gita#core#get_or_fail()
  let args = s:args_from_options(git, options)
  call gita#process#execute(git, args)
  call gita#trigger_modified()
endfunction

function! gita#command#reset#complete(arglead, cmdline, cursorpos) abort
  let parser = s:get_parser()
  return parser.complete(a:arglead, a:cmdline, a:cursorpos)
endfunction

call gita#define_variables('command#reset', {
      \ 'default_options': {},
      \})
