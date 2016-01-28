let s:V = hita#vital()
let s:Dict = s:V.import('Data.Dict')
let s:Path = s:V.import('System.Filepath')
let s:ArgumentParser = s:V.import('ArgumentParser')

function! s:pick_available_options(options) abort
  let options = s:Dict.pick(a:options, [
        \ 'include', 'exclude',
        \ 'p',
        \ 'no-add',
        \ 'stat', 'numstat',
        \ 'summary', 'check',
        \ 'index', 'cached',
        \ 'unsafe-paths',
        \ 'build-fake-ancestor',
        \ 'C',
        \ 'whitespace',
        \ 'ignore-space-change', 'ignore-whitespace',
        \ 'R', 'reverse',
        \ 'unidiff-zero',
        \ 'reject',
        \ 'allow-overlap',
        \ 'v', 'verbose',
        \ 'inaccurate-eof',
        \ 'recount',
        \ 'directory',
        \])
  return options
endfunction
function! s:apply_content(hita, content, options) abort
  let options = s:pick_available_options(a:options)
  let stdin = join(a:content, "\n")
  let result = hita#execute(a:hita, 'apply', options, {
        \  'input': hita#util#string#ensure_eol(stdin),
        \})
  if result.status
    call hita#throw(result.stdout)
  endif
  return split(result.stdout, '\r\?\n', 1)
endfunction
function! s:apply_patches(hita, filenames, options) abort
  let options = s:pick_available_options(a:options)
  let options['--'] = a:filenames
  let result = hita#execute(
        \ a:hita, 'apply', options,
        \)
  if result.status
    call hita#throw(result.stdout)
  endif
  return split(result.stdout, '\r\?\n', 1)
endfunction

function! hita#command#apply#call(...) abort
  let options = hita#option#init('', get(a:000, 0, {}), {
        \ 'diff_content': [],
        \ 'filenames': [],
        \})
  try
    let hita = hita#get_or_fail()
    if empty(options.filenames)
      let filenames = []
      let diff_content = empty(options.diff_content)
            \ ? getline(1, '$')
            \ : options.diff_content
      let content = s:apply_content(hita, diff_content, options)
    else
      let filenames = map(
            \ copy(options.filenames),
            \ 'hita#variable#get_valid_filename(v:val)',
            \)
      let diff_content = []
      let content = s:apply_patches(hita, filenames, options)
    endif
    return {
          \ 'diff_content': diff_content,
          \ 'filenames': filenames,
          \ 'content': content,
          \}
  catch /^\%(vital:\|vim-hita:\)/
    call hita#util#handle_exception(v:exception)
    return {}
  endtry
endfunction

function! s:get_parser() abort
  if !exists('s:parser') || g:hita#develop
    let s:parser = s:ArgumentParser.new({
          \ 'name': 'Hita apply',
          \ 'description': 'Apply patch(es) to the repository',
          \ 'complete_unknown': function('hita#variable#complete_filename'),
          \ 'unknown_description': 'filenames',
          \ 'complete_threshold': g:hita#complete_threshold,
          \})
    call s:parser.add_argument(
          \ '--cached',
          \ 'Directory apply the pathc(es) to INDEX', {
          \})
    " TODO: Add more arguments
  endif
  return s:parser
endfunction
function! hita#command#apply#command(...) abort
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
        \ deepcopy(g:hita#command#apply#default_options),
        \ options,
        \)
  call hita#command#apply#call(options)
endfunction
function! hita#command#apply#complete(...) abort
  let parser = s:get_parser()
  return call(parser.complete, a:000, parser)
endfunction

call hita#define_variables('command#apply', {
      \ 'default_options': {},
      \})
