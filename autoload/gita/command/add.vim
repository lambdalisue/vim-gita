let s:V = gita#vital()
let s:ArgumentParser = s:V.import('ArgumentParser')

function! s:get_parser() abort
  if !exists('s:parser') || g:gita#develop
    let s:parser = s:ArgumentParser.new({
          \ 'name': 'Gita add',
          \ 'description': 'Add file contents to the index',
          \ 'complete_threshold': g:gita#complete_threshold,
          \ 'unknown_description': '<pathspec>...',
          \ 'complete_unknown': function('gita#util#complete#unstaged_filename'),
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

function! s:args_from_options(git, options) abort
  let args = gita#process#args_from_options(a:options, {
        \ 'dry-run': 1,
        \ 'force': 1,
        \ 'update': 1,
        \ 'intent-to-add': 1,
        \ 'all': 1,
        \ 'ignore-removal': 1,
        \ 'refresh': 1,
        \ 'ignore-errors': 1,
        \ 'ignore-missing': 1,
        \})
  let args = ['add', '--verbose'] + args + ['--'] + map(
        \ get(a:options, '__unknown__', []),
        \ 'gita#normalize#abspath(a:git, v:val)'
        \)
  return filter(args, '!empty(v:val)')
endfunction

function! gita#command#add#execute(git, options) abort
  let args = s:args_from_options(a:git, a:options)
  let result = gita#process#execute(a:git, args)
  return result
endfunction

function! gita#command#add#command(bang, range, args) abort
  let git = gita#core#get_or_fail()
  let parser  = s:get_parser()
  let options = parser.parse(a:bang, a:range, a:args)
  if empty(options)
    return {}
  endif
  let options = extend(
        \ copy(g:gita#command#add#default_options),
        \ options
        \)
  let git = gita#core#get_or_fail()
  let result = gita#command#add#execute(git, options)
  if !get(options, 'dry-run')
    call gita#trigger_modified()
  endif
  return result
endfunction

function! gita#command#add#complete(arglead, cmdline, cursorpos) abort
  let parser = s:get_parser()
  return parser.complete(a:arglead, a:cmdline, a:cursorpos)
endfunction

call gita#define_variables('command#add', {
      \ 'default_options': {},
      \})
