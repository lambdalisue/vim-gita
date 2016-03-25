let s:V = gita#vital()
let s:ArgumentParser = s:V.import('ArgumentParser')

function! s:get_parser() abort
  if !exists('s:parser') || g:gita#develop
    let s:parser = s:ArgumentParser.new({
          \ 'name': 'Gita reset',
          \ 'description': 'Reset current HEAD to the specified state',
          \ 'complete_threshold': g:gita#complete_threshold,
          \ 'unknown_description': '<paths>...',
          \ 'complete_unknown': function('gita#complete#filename'),
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
          \   'complete': function('gita#complete#commit'),
          \   'superordinates': [
          \     'mixed', 'soft', 'hard', 'merge', 'keep',
          \   ],
          \})
  endif
  return s:parser
endfunction

function! gita#command#reset#command(bang, range, args) abort
  let parser  = s:get_parser()
  let options = parser.parse(a:bang, a:range, a:args)
  if empty(options)
    return
  endif
  let git = gita#core#get_or_fail()
  call gita#process#execute(git, ['reset'] + options.__args__)
  call gita#util#doautocmd('User', 'GitaStatusModified')
endfunction

function! gita#command#reset#complete(arglead, cmdline, cursorpos) abort
  let parser = s:get_parser()
  return parser.complete(a:arglead, a:cmdline, a:cursorpos)
endfunction
