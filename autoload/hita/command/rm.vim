let s:V = hita#vital()
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
function! s:apply_command(hita, filenames, options) abort
  let options = s:pick_available_options(a:options)
  if !empty(a:filenames)
    let options['--'] = a:filenames
  endif
  let result = hita#execute(a:hita, 'rm', options)
  if result.status
    call s:GitProcess.throw(result.stdout)
  endif
  return result.content
endfunction

function! hita#command#rm#call(...) abort
  let options = hita#option#init('', get(a:000, 0, {}), {
        \ 'filenames': [],
        \})
  let hita = hita#get_or_fail()
  if empty(options.filenames)
    let filenames = []
  else
    let filenames = map(
          \ copy(options.filenames),
          \ 'hita#variable#get_valid_filename(v:val)',
          \)
  endif
  let content = s:apply_command(hita, filenames, options)
  silent call hita#util#doautocmd('StatusModified')
  return {
        \ 'filenames': filenames,
        \ 'content': content,
        \}
endfunction

function! s:get_parser() abort
  if !exists('s:parser') || g:hita#develop
    let s:parser = s:ArgumentParser.new({
          \ 'name': 'Hita rm',
          \ 'description': 'Remove files from the working tree and from the index',
          \ 'complete_unknown': function('hita#variable#complete_filename'),
          \ 'unknown_description': 'filenames',
          \ 'complete_threshold': g:hita#complete_threshold,
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
function! hita#command#rm#command(...) abort
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
        \ deepcopy(g:hita#command#rm#default_options),
        \ options,
        \)
  call hita#command#rm#call(options)
endfunction
function! hita#command#rm#complete(...) abort
  let parser = s:get_parser()
  return call(parser.complete, a:000, parser)
endfunction

call hita#util#define_variables('command#rm', {
      \})
