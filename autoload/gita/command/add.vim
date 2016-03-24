let s:V = gita#vital()
let s:ArgumentParser = s:V.import('ArgumentParser')

function! s:get_parser() abort
  if !exists('s:parser') || g:gita#develop
    let s:parser = s:ArgumentParser.new({
          \ 'name': 'Gita add',
          \ 'description': 'Add file contents to the index',
          \ 'complete_threshold': g:gita#complete_threshold,
          \ 'unknown_description': '<pathspec>...',
          \ 'complete_unknown': function('gita#complete#unstaged_filename'),
          \})
    call s:parser.add_argument(
          \ '--dry-run', '-n',
          \ 'dry run',
          \)
    call s:parser.add_argument(
          \ '--force', '-f',
          \ 'allow adding otherwise ignored files',
          \)
    call s:parser.add_argument(
          \ '--update', '-u',
          \ 'update tracked files',
          \)
    call s:parser.add_argument(
          \ '--intent-to-add', '-N',
          \ 'record only the fact that the patch will be added later',
          \)
    call s:parser.add_argument(
          \ '--all', '-A',
          \ 'add changes from all tracked and untracked files', {
          \   'conflicts': ['ignore-removal'],
          \})
    call s:parser.add_argument(
          \ '--ignore-removal',
          \ 'ignore paths removed in the working tree (opposite to --all)', {
          \   'conflicts': ['all'],
          \})
    call s:parser.add_argument(
          \ '--refresh',
          \ 'don''t add, only refresh the index',
          \)
    call s:parser.add_argument(
          \ '--ignore-errors',
          \ 'just skip files which cannot be added because of errors',
          \)
    call s:parser.add_argument(
          \ '--ignore-missing',
          \ 'check if - even missing - files are ignored in dry run',
          \)
  endif
  return s:parser
endfunction

function! gita#command#add#command(bang, range, args) abort
  let parser  = s:get_parser()
  let options = parser.parse(a:bang, a:range, a:args)
  if empty(options)
    return
  endif
  call gita#execute(['add'] + options.__args__ + ['--'] + options.__unknown__)
  if !get(options, 'dry-run')
    call gita#util#doautocmd('User', 'GitaStatusModified')
  endif
endfunction

function! gita#command#add#complete(arglead, cmdline, cursorpos) abort
  let parser = s:get_parser()
  return parser.complete(a:arglead, a:cmdline, a:cursorpos)
endfunction
