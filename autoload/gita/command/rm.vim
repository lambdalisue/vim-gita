let s:V = gita#vital()
let s:ArgumentParser = s:V.import('ArgumentParser')

function! s:get_parser() abort
  if !exists('s:parser') || g:gita#develop
    let s:parser = s:ArgumentParser.new({
          \ 'name': 'Gita rm',
          \ 'description': 'Remove files from the working tree and from the index',
          \ 'complete_threshold': g:gita#complete_threshold,
          \ 'unknown_description': '<file>...',
          \ 'complete_unknown': function('gita#util#complete#filename'),
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

function! s:args_from_options(git, options) abort
  let args = gita#process#args_from_options(a:options, {
        \ 'dry-run': 1,
        \ 'force': 1,
        \ 'r': 1,
        \ 'cached': 1,
        \ 'ignore-unmatch': 1,
        \})
  let args = ['rm'] + args + ['--'] + map(
        \ get(a:options, '__unknown__', []),
        \ 'gita#normalize#abspath(a:git, v:val)'
        \)
  return filter(args, '!empty(v:val)')
endfunction

function! gita#command#rm#command(bang, range, args) abort
  let git = gita#core#get_or_fail()
  let parser  = s:get_parser()
  let options = parser.parse(a:bang, a:range, a:args)
  if empty(options)
    return
  endif
  let options = extend(
        \ copy(g:gita#command#rm#default_options),
        \ options
        \)
  let git = gita#core#get_or_fail()
  let args = s:args_from_options(git, options)
  call gita#process#execute(git, args)
  if !get(options, 'dry-run')
    call gita#trigger_modified()
  endif
endfunction

function! gita#command#rm#complete(arglead, cmdline, cursorpos) abort
  let parser = s:get_parser()
  return parser.complete(a:arglead, a:cmdline, a:cursorpos)
endfunction

call gita#define_variables('command#rm', {
      \ 'default_options': {},
      \})
