let s:V = gita#vital()
let s:ArgumentParser = s:V.import('ArgumentParser')

function! s:get_parser() abort
  if !exists('s:parser') || g:gita#develop
    let s:parser = s:ArgumentParser.new({
          \ 'name': 'Gita init',
          \ 'description': 'Create an empty Git repository or reinitialize an existing one',
          \ 'complete_threshold': g:gita#complete_threshold,
          \})
    call s:parser.add_argument(
          \ '--bare',
          \ 'create a bare repository',
          \)
    call s:parser.add_argument(
          \ '--template',
          \ 'specify the directory from which templates will be used', {
          \   'complete': function('gita#complete#directory'),
          \})
    call s:parser.add_argument(
          \ '--separate-git-dir', [
          \   'instead of initializing the repository as a directory,',
          \   'create a text file there containgthe path to the actual repository',
          \ ], {
          \   'complete': function('gita#complete#directory'),
          \})
    call s:parser.add_argument(
          \ '--shared', [
          \ 'specify that the Git repository is to be shared amongst several users', {
          \   'pattern': '^\%(false\|true\|umask\|group|all\|world\|everyone\|0\d\{3}\)$',
          \})
  endif
  return s:parser
endfunction

function! gita#command#init#command(bang, range, args) abort
  let parser = s:get_parser()
  let options = parser.parse(a:bang, a:range, a:args)
  if empty(options)
    return
  endif
  call gita#command#execute(['init'] + options.__args__)
  call gita#core#expire()
  call gita#util#doautocmd('User', 'GitaStatusModified')
endfunction

function! gita#command#init#complete(arglead, cmdline, cursorpos) abort
  let parser = s:get_parser()
  return parser.complete(a:arglead, a:cmdline, a:cursorpos)
endfunction
