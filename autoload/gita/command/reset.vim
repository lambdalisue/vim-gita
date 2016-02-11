let s:V = gita#vital()
let s:Dict = s:V.import('Data.Dict')
let s:Path = s:V.import('System.Filepath')
let s:Prompt = s:V.import('Vim.Prompt')
let s:Git = s:V.import('Git')
let s:GitProcess = s:V.import('Git.Process')
let s:ArgumentParser = s:V.import('ArgumentParser')

function! s:pick_available_options(options) abort
  " Note:
  " Let me know or send me a PR if you need options not listed below
  let options = s:Dict.pick(a:options, [
        \ 'soft',
        \ 'mixed',
        \ 'N',
        \ 'hard',
        \ 'merge',
        \ 'keep',
        \ 'commit',
        \])
  return options
endfunction
function! s:apply_command(git, filenames, options) abort
  let options = s:pick_available_options(a:options)
  if !empty(a:filenames)
    " NOTE:
    " git reset requires relative paths from repository root
    let options['--'] = map(
          \ copy(a:filenames),
          \ 's:Path.unixpath(s:Git.get_relative_path(a:git, v:val))',
          \)
  endif
  let result = gita#execute(a:git, 'reset', options)
  if result.status
    call s:GitProcess.throw(result.stdout)
  elseif !get(a:options, 'quiet', 0)
    call s:Prompt.title('OK: ' . join(result.args, ' '))
    echo join(result.content, "\n")
  endif
  return result.content
endfunction

function! gita#command#reset#call(...) abort
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
function! gita#command#reset#patch(...) abort
  let options = gita#option#init('', get(a:000, 0, {}), {
        \ 'filenames': [],
        \})
  let filename = len(options.filenames) > 0
        \ ? options.filenames[0]
        \ : '%'
  if get(options, 'split')
    call gita#command#diff#open2({
          \ 'patch': 1,
          \ 'commit': 'HEAD',
          \ 'filename': filename,
          \})
  else
    call gita#command#diff#open({
          \ 'patch': 1,
          \ 'commit': 'HEAD',
          \ 'filename': filename,
          \})
  endif
endfunction

function! s:get_parser() abort
  if !exists('s:parser') || g:gita#develop
    let s:parser = s:ArgumentParser.new({
          \ 'name': 'Gita reset',
          \ 'description': 'Reset current HEAD to the specified state',
          \ 'complete_unknown': function('gita#variable#complete_filename'),
          \ 'unknown_description': '<paths>...',
          \ 'complete_threshold': g:gita#complete_threshold,
          \})
    call s:parser.add_argument(
          \ '--quiet', '-q',
          \ 'be quiet',
          \)
    call s:parser.add_argument(
          \ '--mixed',
          \ 'reset HEAD and index',
          \)
    call s:parser.add_argument(
          \ '--intent-to-add', '-N',
          \ 'record only the fact that removed paths will be added later', {
          \   'superordinates': ['mixed'],
          \})
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
          \ '--patch', '-p',
          \ 'An alias option for ":Gita diff --patch HEAD -- %" to perform HEAD -> index patch', {
          \   'conflicts': [
          \     'mixed', 'soft', 'hard', 'merge', 'keep',
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
function! gita#command#reset#command(...) abort
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
        \ deepcopy(g:gita#command#reset#default_options),
        \ options,
        \)
  if get(options, 'patch')
    call gita#command#reset#patch(options)
  else
    call gita#command#reset#call(options)
  endif
endfunction
function! gita#command#reset#complete(...) abort
  let parser = s:get_parser()
  return call(parser.complete, a:000, parser)
endfunction

call gita#util#define_variables('command#reset', {
      \ 'default_options': {},
      \})
