let s:V = gita#vital()
let s:Dict = s:V.import('Data.Dict')
let s:ArgumentParser = s:V.import('ArgumentParser')

function! s:execute_command(git, filenames, options) abort
  let args = gita#util#args_from_options(a:options, {
        \ 'dry-run': 1,
        \ 'force': 1,
        \ 'update': 1,
        \ 'all': 1,
        \ 'ignore-removal': 1,
        \ 'intent-to-add': 1,
        \ 'refresh': 1,
        \ 'ignore-errors': 1,
        \ 'ignore-missing': 1,
        \})
  let args = ['add'] + args + ['--'] + a:filenames
  return gita#execute(a:git, args, s:Dict.pick(a:options, [
        \ 'quiet', 'fail_silently',
        \]))
endfunction

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
          \ '--quiet',
          \ 'be quiet',
          \)
    call s:parser.add_argument(
          \ '--dry-run', '-n',
          \ 'dry run', {
          \   'conflicts': ['edit', 'patch'],
          \})
    call s:parser.add_argument(
          \ '--force', '-f',
          \ 'allow adding otherwise ignored files', {
          \   'conflicts': ['edit', 'patch'],
          \})
    call s:parser.add_argument(
          \ '--update', '-u',
          \ 'update tracked files', {
          \   'conflicts': ['edit', 'patch'],
          \})
    call s:parser.add_argument(
          \ '--intent-to-add', '-N',
          \ 'record only the fact that the patch will be added later', {
          \   'conflicts': ['edit', 'patch'],
          \})
    call s:parser.add_argument(
          \ '--all', '-A',
          \ 'add changes from all tracked and untracked files', {
          \   'conflicts': ['ignore-removal', 'edit', 'patch'],
          \})
    call s:parser.add_argument(
          \ '--ignore-removal',
          \ 'ignore paths removed in the working tree (opposite to --all)', {
          \   'conflicts': ['all', 'edit', 'patch'],
          \})
    call s:parser.add_argument(
          \ '--refresh',
          \ 'don''t add, only refresh the index', {
          \   'conflicts': ['edit', 'patch'],
          \})
    call s:parser.add_argument(
          \ '--ignore-errors',
          \ 'just skip files which cannot be added because of errors', {
          \   'conflicts': ['edit', 'patch'],
          \})
    call s:parser.add_argument(
          \ '--ignore-missing',
          \ 'check if - even missing - files are ignored in dry run', {
          \   'conflicts': ['edit', 'patch'],
          \})
    call s:parser.add_argument(
          \ '--edit', '-e', [
          \   'open the diff vs. the index in a buffer and let the user edit it.',
          \   'this is an alias option for :Gita patch --one %',
          \], {
          \   'conflicts': [
          \     'patch',
          \     'dry-run', 'force', 'update', 'intent-to-add', 'all',
          \     'ignore-removal', 'refresh', 'ignore-errors', 'ignore-missing',
          \   ],
          \})
    call s:parser.add_argument(
          \ '--patch', '-p', [
          \   'open the diff vs. the index in two buffers and let the user edit it.',
          \   'this is an alias option for :Gita patch --two %',
          \], {
          \   'conflicts': [
          \     'edit',
          \     'dry-run', 'force', 'update', 'intent-to-add', 'all',
          \     'ignore-removal', 'refresh', 'ignore-errors', 'ignore-missing',
          \   ],
          \})
  endif
  return s:parser
endfunction

function! gita#command#add#call(...) abort
  let options = extend({
        \ 'filenames': [],
        \}, get(a:000, 0, {}))
  let git = gita#core#get_or_fail()
  let filenames = map(
        \ copy(options.filenames),
        \ 'gita#variable#get_valid_filename(git, v:val)',
        \)
  let content = s:execute_command(git, filenames, options)
  call gita#util#doautocmd('User', 'GitaStatusModified')
  return {
        \ 'filenames': filenames,
        \ 'content': content,
        \ 'options': options,
        \}
endfunction

function! gita#command#add#command(...) abort
  let parser  = s:get_parser()
  let options = call(parser.parse, a:000, parser)
  if empty(options)
    return
  endif
  " extend default options
  let options = extend(
        \ deepcopy(g:gita#command#add#default_options),
        \ options,
        \)
  call gita#option#assign_filenames(options)
  if get(options, 'edit') || get(options, 'patch')
    call gita#option#assign_selection(options)
    call gita#option#assign_opener(options)
    call gita#command#ui#add#open(options)
  else
    call gita#command#add#call(options)
  endif
endfunction

function! gita#command#add#complete(...) abort
  let parser = s:get_parser()
  return call(parser.complete, a:000, parser)
endfunction

call gita#util#define_variables('command#add', {
      \ 'default_options': {},
      \})
