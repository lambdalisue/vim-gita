let s:V = gita#vital()
let s:Dict = s:V.import('Data.Dict')
let s:Path = s:V.import('System.Filepath')
let s:Git = s:V.import('Git')
let s:GitProcess = s:V.import('Git.Process')
let s:ArgumentParser = s:V.import('ArgumentParser')

function! s:pick_available_options(options) abort
  " Note:
  " Let me know or send me a PR if you need options not listed below
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
    let options['--'] = map(
          \ copy(a:filenames),
          \ 's:Path.unixpath(s:Git.get_relative_path(a:git, v:val))',
          \)
  endif
  let result = gita#execute(a:git, 'reset', options)
  if result.status
    call s:GitProcess.throw(result.stdout)
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

function! s:get_parser() abort
  if !exists('s:parser') || g:gita#develop
    let s:parser = s:ArgumentParser.new({
          \ 'name': 'Gita reset',
          \ 'description': 'Reset changes on index',
          \ 'complete_unknown': function('gita#variable#complete_filename'),
          \ 'unknown_description': 'filenames',
          \ 'complete_threshold': g:gita#complete_threshold,
          \})
    " TODO: Add more arguments
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
  call gita#command#reset#call(options)
endfunction
function! gita#command#reset#complete(...) abort
  let parser = s:get_parser()
  return call(parser.complete, a:000, parser)
endfunction

call gita#util#define_variables('command#reset', {
      \ 'default_options': {},
      \})

