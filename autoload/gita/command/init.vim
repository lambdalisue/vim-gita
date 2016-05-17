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
          \   'complete': function('gita#util#complete#directory'),
          \})
    call s:parser.add_argument(
          \ '--separate-git-dir', [
          \   'instead of initializing the repository as a directory,',
          \   'create a text file there containgthe path to the actual repository',
          \ ], {
          \   'complete': function('gita#util#complete#directory'),
          \})
    call s:parser.add_argument(
          \ '--shared',
          \ 'specify that the Git repository is to be shared amongst several users', {
          \   'pattern': '^\%(false\|true\|umask\|group|all\|world\|everyone\|0\d\{3}\)$',
          \})
  endif
  return s:parser
endfunction

function! s:args_from_options(git, options) abort
  let args = gita#process#args_from_options(a:options, {
        \ 'bare': 1,
        \ 'template': 1,
        \ 'separate-git-dir': 1,
        \ 'shared': 1,
        \})
  let args = ['init'] + args
  return filter(args, '!empty(v:val)')
endfunction

function! gita#command#init#execute(git, options) abort
  let args = s:args_from_options(a:git, a:options)
  let result = gita#process#execute(a:git, args)
  return result
endfunction

function! gita#command#init#command(bang, range, args) abort
  let git = gita#core#get()
  let parser = s:get_parser()
  let options = parser.parse(a:bang, a:range, a:args)
  if empty(options)
    return {}
  endif
  let options = extend(
        \ copy(g:gita#command#init#default_options),
        \ options
        \)
  " NOTE:
  " init command might be executed in non git repository
  let git = gita#core#get()
  let result = gita#command#init#execute(git, options)
  call gita#core#expire()
  call gita#trigger_modified()
  return result
endfunction

function! gita#command#init#complete(arglead, cmdline, cursorpos) abort
  let parser = s:get_parser()
  return parser.complete(a:arglead, a:cmdline, a:cursorpos)
endfunction

call gita#define_variables('command#init', {
      \ 'default_options': {},
      \})
