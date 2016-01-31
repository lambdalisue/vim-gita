let s:V = gita#vital()
let s:Dict = s:V.import('Data.Dict')
let s:Prompt = s:V.import('Vim.Prompt')
let s:GitProcess = s:V.import('Git.Process')
let s:ArgumentParser = s:V.import('ArgumentParser')

function! s:pick_available_options(options) abort
  " Note:
  " Let me know or send me a PR if you need options not listed below
  let options = s:Dict.pick(a:options, [
        \ 'f', 'force',
        \ 'u', 'update',
        \ 'A', 'all',
        \ 'ignore-removal',
        \ 'ignore-errors',
        \])
  return options
endfunction
function! s:apply_command(git, filenames, options) abort
  let options = s:pick_available_options(a:options)
  if !empty(a:filenames)
    let options['--'] = a:filenames
  endif
  let result = gita#execute(a:git, 'add', options)
  if result.status
    call s:GitProcess.throw(result)
  endif
  return result.content
endfunction

function! gita#command#add#call(...) abort
  let options = gita#option#init('', get(a:000, 0, {}), {
        \ 'filenames': [],
        \})
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
  call gita#util#doautocmd('StatusModified')
  return {
        \ 'filenames': filenames,
        \ 'content': content,
        \ 'options': options,
        \}
endfunction
function! gita#command#add#patch(...) abort
  let options = gita#option#init('', get(a:000, 0, {}), {
        \ 'filenames': [],
        \})
  let filename = len(options.filenames) > 0
        \ ? options.filenames[0]
        \ : '%'
  call gita#command#diff#open2({
        \ 'patch': 1,
        \ 'commit': '',
        \ 'filenames': [filename],
        \})
endfunction

function! s:get_parser() abort
  if !exists('s:parser') || g:gita#develop
    let s:parser = s:ArgumentParser.new({
          \ 'name': 'Gita add',
          \ 'description': 'Add changes into the index',
          \ 'complete_unknown': function('gita#variable#complete_filename'),
          \ 'unknown_description': 'filenames',
          \ 'complete_threshold': g:gita#complete_threshold,
          \})
    call s:parser.add_argument(
          \ '--force', '-f',
          \ 'Allow adding otherwise ignored files.',
          \)
    call s:parser.add_argument(
          \ '--update', '-u', [
          \   'Update the index just where it already has an entry matching <pathspec>.',
          \   'This removes as well as modifies index entries to match the working tree,',
          \   'but adds no new files.',
          \   'If no <pathspec> is given when -u option is used, all tracked files in the',
          \   'entire working tree are updated.',
          \ ]
          \)
    call s:parser.add_argument(
          \ '--all', '-A', [
          \   'Update the index not only where the working tree has a file matching <pathspec>',
          \   'but also where the index already has an entry. This adds, modifies, and removes',
          \   'index entries to match the working tree.',
          \   'If no <pathspec> is given when -A option is used, all files in the entire working',
          \   'tree are updated.',
          \ ], {
          \   'deniable': 1,
          \   'conflicts': ['ignore-removal'],
          \})
    call s:parser.add_argument(
          \ '--ignore-removal', [
          \   'Update the index by adding new files that are unknown to the index and files modified',
          \   'in the working tree, but ignore files that have been removed from the working tree.',
          \   'This option is a no0op when no <pathspec> is used.',
          \ ], {
          \   'deniable': 1,
          \   'conflicts': ['all'],
          \})
    call s:parser.add_argument(
          \ '--ignore-errors', [
          \ 'If some files could not be added because of errors indexing them, do not abort the operation,',
          \ 'but continue adding the others. The command shall still exit with non-zero status.',
          \])
    call s:parser.add_argument(
          \ '--patch', '-p', [
          \ 'An alias option for ":Gita diff --patch -- %" to perform working tree -> index patch',
          \])
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
