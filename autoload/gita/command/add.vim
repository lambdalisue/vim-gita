let s:V = gita#vital()
let s:Dict = s:V.import('Data.Dict')
let s:Prompt = s:V.import('Vim.Prompt')
let s:GitProcess = s:V.import('Git.Process')
let s:ArgumentParser = s:V.import('ArgumentParser')

function! s:pick_available_options(options) abort
  " Note:
  " Let me know or send me a PR if you need options not listed below
  return s:Dict.pick(a:options, [
        \ 'dry-run',
        \ 'force',
        \ 'update',
        \ 'all',
        \ 'ignore-removal',
        \ 'intent-to-add',
        \ 'refresh',
        \ 'ignore-errors',
        \ 'ignore-missing',
        \])
endfunction
function! s:apply_command(git, filenames, options) abort
  let options = s:pick_available_options(a:options)
  let options['verbose'] = 1
  if !empty(a:filenames)
    let options['--'] = a:filenames
  endif
  let result = gita#execute(a:git, 'add', options)
  if result.status
    call s:GitProcess.throw(result)
  elseif !get(a:options, 'quiet')
    call s:Prompt.title('OK: ' . join(result.args, ' '))
    echo join(result.content, "\n")
  endif
  return result.content
endfunction

function! gita#command#add#call(...) abort
  let options = extend({
        \ 'filenames': [],
        \}, get(a:000, 0, {}))
  let git = gita#get_or_fail()
  if empty(options.filenames)
    let filenames = []
  else
    let filenames = map(
          \ copy(options.filenames),
          \ 'gita#variable#get_valid_filename(v:val)',
          \)
  endif
  let content = s:apply_command(git, filenames, options)
  call gita#util#doautocmd('User', 'GitaStatusModified')
  return {
        \ 'filenames': filenames,
        \ 'content': content,
        \ 'options': options,
        \}
endfunction
function! gita#command#add#patch(...) abort
  let options = extend({
        \ 'filenames': [],
        \ 'split': 0,
        \}, get(a:000, 0, {}))
  let filename = len(options.filenames) > 0
        \ ? options.filenames[0]
        \ : '%'
  call gita#command#patch#open({
        \ 'method': options.split ? 'two' : 'one',
        \ 'filename': filename,
        \})
endfunction

function! s:get_parser() abort
  if !exists('s:parser') || g:gita#develop
    let s:parser = s:ArgumentParser.new({
          \ 'name': 'Gita add',
          \ 'description': 'Add file contents to the index',
          \ 'complete_unknown': function('gita#variable#complete_filename'),
          \ 'unknown_description': '<pathspec>...',
          \ 'complete_threshold': g:gita#complete_threshold,
          \})
    call s:parser.add_argument(
          \ '--quiet',
          \ 'be quiet',
          \)
    call s:parser.add_argument(
          \ '--dry-run', '-n',
          \ 'dry run', {
          \   'conflicts': ['patch'],
          \})
    call s:parser.add_argument(
          \ '--force', '-f',
          \ 'allow adding otherwise ignored files', {
          \   'conflicts': ['patch'],
          \})
    call s:parser.add_argument(
          \ '--update', '-u',
          \ 'update tracked files', {
          \   'conflicts': ['patch'],
          \})
    call s:parser.add_argument(
          \ '--intent-to-add', '-N',
          \ 'record only the fact that the patch will be added later', {
          \   'conflicts': ['patch'],
          \})
    call s:parser.add_argument(
          \ '--all', '-A',
          \ 'add changes from all tracked and untracked files', {
          \   'conflicts': ['ignore-removal', 'patch'],
          \})
    call s:parser.add_argument(
          \ '--ignore-removal',
          \ 'ignore paths removed in the working tree (opposite to --all)', {
          \   'conflicts': ['all', 'patch'],
          \})
    call s:parser.add_argument(
          \ '--refresh',
          \ 'don''t add, only refresh the index', {
          \   'conflicts': ['patch'],
          \})
    call s:parser.add_argument(
          \ '--ignore-errors',
          \ 'just skip files which cannot be added because of errors', {
          \   'conflicts': ['patch'],
          \})
    call s:parser.add_argument(
          \ '--ignore-missing',
          \ 'check if - even missing - files are ignored in dry run', {
          \   'conflicts': ['patch'],
          \})
    call s:parser.add_argument(
          \ '--patch', '-p',
          \ 'An alias option for ":Gita patch --one %" to perform working tree -> index patch', {
          \   'conflicts': [
          \     'dry-run', 'force', 'update', 'intent-to-add', 'all',
          \     'ignore-removal', 'refresh', 'ignore-errors', 'ignore-missing',
          \   ],
          \})
    call s:parser.add_argument(
          \ '--split', '-s',
          \ 'A subordinate option of --patch to show two buffers instead of a single diff.', {
          \   'superordinates': ['patch'],
          \})
  endif
  return s:parser
endfunction
function! gita#command#add#command(...) abort
  let parser  = s:get_parser()
  let options = call(parser.parse, a:000, parser)
  if empty(options)
    return
  endif
  if !empty(options.__unknown__)
    let options.filenames = options.__unknown__
  endif
  " extend default options
  let options = extend(
        \ deepcopy(g:gita#command#add#default_options),
        \ options,
        \)
  if get(options, 'patch')
    call gita#command#add#patch(options)
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
