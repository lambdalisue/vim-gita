let s:V = hita#vital()
let s:Dict = s:V.import('Data.Dict')
let s:GitProcess = s:V.import('Git.Process')
let s:ArgumentParser = s:V.import('ArgumentParser')

function! s:pick_available_options(options) abort
  let options = s:Dict.pick(a:options, [
        \ 'q', 'quiet',
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
    " Convert a real absolute path into unix relative path
    let options['--'] = a:filenames
  endif
  let result = hita#execute(a:git, 'reset', options)
  if result.status
    call s:GitProcess.throw(result.stdout)
  endif
  return result.content
endfunction

function! hita#command#reset#call(...) abort
  let options = hita#option#init('', get(a:000, 0, {}), {
        \ 'filenames': [],
        \})
  let git = hita#get_or_fail()
  if empty(options.filenames)
    let filenames = []
  else
    let filenames = map(
          \ copy(options.filenames),
          \ 'hita#variable#get_valid_filename(v:val)',
          \)
  endif
  let content = s:apply_command(git, filenames, options)
  call hita#util#doautocmd('StatusModified')
  return {
        \ 'filenames': filenames,
        \ 'content': content,
        \}
endfunction

function! s:get_parser() abort
  if !exists('s:parser') || g:hita#develop
    let s:parser = s:ArgumentParser.new({
          \ 'name': 'Hita reset',
          \ 'description': 'Reset changes on index',
          \ 'complete_unknown': function('hita#variable#complete_filename'),
          \ 'unknown_description': 'filenames',
          \ 'complete_threshold': g:hita#complete_threshold,
          \})
    " TODO: Add more arguments
  endif
  return s:parser
endfunction
function! hita#command#reset#command(...) abort
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
        \ deepcopy(g:hita#command#reset#default_options),
        \ options,
        \)
  call hita#command#reset#call(options)
endfunction
function! hita#command#reset#complete(...) abort
  let parser = s:get_parser()
  return call(parser.complete, a:000, parser)
endfunction

call hita#util#define_variables('command#reset', {
      \ 'default_options': {},
      \})

