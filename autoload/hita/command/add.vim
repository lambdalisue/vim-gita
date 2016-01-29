let s:V = hita#vital()
let s:Dict = s:V.import('Data.Dict')
let s:ArgumentParser = s:V.import('ArgumentParser')

function! s:pick_available_options(options) abort
  let options = s:Dict.pick(a:options, [
        \ 'v', 'verbose',
        \ 'f', 'force',
        \ 'A', 'all',
        \ 'ignore-removal',
        \ 'ignore-errors',
        \])
  return options
endfunction
function! s:apply_command(hita, filenames, options) abort
  let options = s:pick_available_options(a:options)
  if !empty(a:filenames)
    let options['--'] = a:filenames
  endif
  let result = hita#execute(a:hita, 'add', options)
  if result.status
    call hita#throw(result.stdout)
  endif
  return result.content
endfunction

function! hita#command#add#call(...) abort
  let options = hita#option#init('', get(a:000, 0, {}), {
        \ 'filenames': [],
        \})
  try
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
  catch /^\%(vital: Git[:.]\|vim-hita:\)/
    call hita#util#handle_exception(v:exception)
    return {}
  endtry
endfunction

function! s:get_parser() abort
  if !exists('s:parser') || g:hita#develop
    let s:parser = s:ArgumentParser.new({
          \ 'name': 'Hita add',
          \ 'description': 'Add changes into index',
          \ 'complete_unknown': function('hita#variable#complete_filename'),
          \ 'unknown_description': 'filenames',
          \ 'complete_threshold': g:hita#complete_threshold,
          \})
    call s:parser.add_argument(
          \ '--force', '-f',
          \ 'Allow adding otherwise ignored files.',
          \)
    " TODO: Add more arguments
  endif
  return s:parser
endfunction
function! hita#command#add#command(...) abort
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
        \ deepcopy(g:hita#command#add#default_options),
        \ options,
        \)
  call hita#command#add#call(options)
endfunction
function! hita#command#add#complete(...) abort
  let parser = s:get_parser()
  return call(parser.complete, a:000, parser)
endfunction

call hita#util#define_variables('command#add', {
      \ 'default_options': {},
      \})
