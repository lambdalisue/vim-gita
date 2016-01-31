let s:V = gita#vital()
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
function! s:apply_patches(git, filenames, options) abort
  let options = s:pick_available_options(a:options)
  let options['--'] = a:filenames
  let result = gita#execute(a:git, 'apply', options)
  if result.status
    call s:GitProcess.throw(result.stdout)
  endif
  return result.content
endfunction

function! gita#command#apply#call(...) abort
  let options = gita#option#init('', get(a:000, 0, {}), {
        \ 'filenames': [],
        \})
  let git = gita#get_or_fail()
  if empty(options.filenames)
    call gita#throw('ValidationError: "filenames" cannot be empty')
  endif
  let filenames = map(
        \ copy(options.filenames),
        \ 'gita#variable#get_valid_filename(v:val)',
        \)
  let content = s:apply_patches(git, filenames, options)
  call gita#util#doautocmd('StatusModified')
  return {
        \ 'filenames': filenames,
        \ 'content': content,
        \}
endfunction

function! s:get_parser() abort
  if !exists('s:parser') || g:gita#develop
    let s:parser = s:ArgumentParser.new({
          \ 'name': 'Gita apply',
          \ 'description': 'Apply patch(es) to the repository',
          \ 'complete_unknown': function('gita#variable#complete_filename'),
          \ 'unknown_description': 'filenames',
          \ 'complete_threshold': g:gita#complete_threshold,
          \})
    call s:parser.add_argument(
          \ '--cached',
          \ 'Directory apply the pathc(es) to INDEX', {
          \})
    " TODO: Add more arguments
  endif
  return s:parser
endfunction
function! gita#command#apply#command(...) abort
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
        \ deepcopy(g:gita#command#apply#default_options),
        \ options,
        \)
  call gita#command#apply#call(options)
endfunction
function! gita#command#apply#complete(...) abort
  let parser = s:get_parser()
  return call(parser.complete, a:000, parser)
endfunction

call gita#util#define_variables('command#apply', {
      \})
