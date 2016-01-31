let s:V = gita#vital()
let s:Dict = s:V.import('Data.Dict')
let s:GitProcess = s:V.import('Git.Process')
let s:ArgumentParser = s:V.import('ArgumentParser')

function! s:pick_available_options(options) abort
  let options = s:Dict.pick(a:options, [
        \ 'q', 'quiet',
        \ 'f', 'force',
        \ 'r', 'recursive',
        \ 'cached',
        \])
  return options
endfunction
function! s:apply_command(git, filenames, options) abort
  let options = s:pick_available_options(a:options)
  if !empty(a:filenames)
    let options['--'] = a:filenames
  endif
  let result = gita#execute(a:git, 'rm', options)
  if result.status
    call s:GitProcess.throw(result.stdout)
  endif
  return result.content
endfunction

function! gita#command#rm#call(...) abort
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
        \}
endfunction

function! s:get_parser() abort
  if !exists('s:parser') || g:gita#develop
    let s:parser = s:ArgumentParser.new({
          \ 'name': 'Gita rm',
          \ 'description': 'Remove files from the working tree and from the index',
          \ 'complete_unknown': function('gita#variable#complete_filename'),
          \ 'unknown_description': 'filenames',
          \ 'complete_threshold': g:gita#complete_threshold,
          \})
    call s:parser.add_argument(
          \ '--quiet', '-q', [
          \   'Gita rm normally outputs one line (in the form of an rm command) for each file removed.',
          \   'This option suppresses that output.',
          \])
    call s:parser.add_argument(
          \ '--force', '-f',
          \ 'Override the up-to-date check.',
          \)
    call s:parser.add_argument(
          \ '--recursive', '-r',
          \ 'Allow recursive removal when a leading directory name is given.',
          \)
    call s:parser.add_argument(
          \ '--cached', [
          \   'Use this option to unstage and remove path only from the index.',
          \   'Working tree files, whether modified or not, will be left alone.',
          \])
    " TODO: Add more arguments
  endif
  return s:parser
endfunction
function! gita#command#rm#command(...) abort
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
        \ deepcopy(g:gita#command#rm#default_options),
        \ options,
        \)
  call gita#command#rm#call(options)
endfunction
function! gita#command#rm#complete(...) abort
  let parser = s:get_parser()
  return call(parser.complete, a:000, parser)
endfunction

call gita#util#define_variables('command#rm', {
      \})

