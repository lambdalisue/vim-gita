let s:V = hita#vital()
let s:Dict = s:V.import('Data.Dict')
let s:GitProcess = s:V.import('Git.Process')
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
  let options['--'] = ['-']
  let result = hita#execute(a:hita, 'apply', options, {
        \ 'input': a:content,
        \})
  if result.status
    call s:GitProcess.throw(result.stdout)
  endif
  return result.content
endfunction
function! s:apply_patches(hita, filenames, options) abort
  let options = s:pick_available_options(a:options)
  let options['--'] = a:filenames
  let result = hita#execute(a:hita, 'apply', options)
  if result.status
    call s:GitProcess.throw(result.stdout)
  endif
  return result.content
endfunction

function! hita#command#apply#call(...) abort
  let options = hita#option#init('', get(a:000, 0, {}), {
        \ 'diff': [],
        \ 'filenames': [],
        \})
  let hita = hita#get_or_fail()
  if empty(options.filenames)
    let filenames = []
    let diff = empty(options.diff) ? getline(1, '$') : options.diff
    let content = s:apply_content(hita, diff, options)
  else
    let filenames = map(
          \ copy(options.filenames),
          \ 'hita#variable#get_valid_filename(v:val)',
          \)
    let diff = []
    let content = s:apply_patches(hita, filenames, options)
  endif
  call hita#util#doautocmd('StatusModified')
  return {
        \ 'diff': diff,
        \ 'filenames': filenames,
        \ 'content': content,
        \}
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

call hita#util#define_variables('command#apply', {
      \})
