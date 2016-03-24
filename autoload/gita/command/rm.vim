let s:V = gita#vital()
let s:ArgumentParser = s:V.import('ArgumentParser')

function! s:get_parser() abort
  if !exists('s:parser') || g:gita#develop
    let s:parser = s:ArgumentParser.new({
          \ 'name': 'Gita rm',
          \ 'description': 'Remove files from the working tree and from the index',
          \ 'complete_threshold': g:gita#complete_threshold,
          \ 'unknown_description': '<file>...',
          \ 'complete_unknown': function('gita#complete#filename'),
          \})
    call s:parser.add_argument(
          \ '--dry-run', '-n',
          \ 'dry run',
          \)
    call s:parser.add_argument(
          \ '--force', '-f',
          \ 'override the up-to-date check',
          \)
    call s:parser.add_argument(
          \ '-r',
          \ 'allow recursive removal',
          \)
    call s:parser.add_argument(
          \ '--cached',
          \ 'only remove from the index',
          \)
    call s:parser.add_argument(
          \ '--ignore-unmatch',
          \ 'exit with a zero status even if nothing matched',
          \)
  endif
  return s:parser
endfunction

function! gita#command#rm#command(bang, range, args) abort
  let parser  = s:get_parser()
  let options = parser.parse(a:bang, a:range, a:args)
  if empty(options)
    return
  endif
  call gita#execute(['rm'] + options.__args__ + ['--'] + options.__unknown__)
  if !get(options, 'dry-run')
    call gita#util#doautocmd('User', 'GitaStatusModified')
  endif
endfunction

function! gita#command#rm#complete(arglead, cmdline, cursorpos) abort
  let parser = s:get_parser()
  return parser.complete(a:arglead, a:cmdline, a:cursorpos)
endfunction
