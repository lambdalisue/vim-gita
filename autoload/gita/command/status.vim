let s:V = gita#vital()
let s:ArgumentParser = s:V.import('ArgumentParser')

function! s:get_parser() abort
  if !exists('s:parser') || g:gita#develop
    let s:parser = s:ArgumentParser.new({
          \ 'name': 'Gita status',
          \ 'description': 'Show and manipulate a status of the repository',
          \ 'complete_threshold': g:gita#complete_threshold,
          \})
    call s:parser.add_argument(
          \ '--ignored',
          \ 'show ignored files as well'
          \)
    call s:parser.add_argument(
          \ '--ignore-submodules',
          \ 'ignore changes to submodules when looking for changes', {
          \   'choices': ['none', 'untracked', 'dirty', 'all'],
          \   'on_default': 'all',
          \})
    call s:parser.add_argument(
          \ '--untracked-files', '-u',
          \ 'show untracked files, optional modes: all, normal, no', {
          \   'choices': ['all', 'normal', 'no'],
          \   'on_default': 'all',
          \})
    call s:parser.add_argument(
          \ '--opener', '-o',
          \ 'a way to open a new buffer such as "edit", "split", etc.', {
          \   'type': s:ArgumentParser.types.value,
          \})
  endif
  return s:parser
endfunction

function! gita#command#status#command(bang, range, args) abort
  let parser = s:get_parser()
  let options = parser.parse(a:bang, a:range, a:args)
  if empty(options)
    return
  endif
  let options = extend(
        \ copy(g:gita#command#status#default_options),
        \ options
        \)
  call gita#util#option#assign_opener(options)
  call gita#content#status#open(options)
endfunction

function! gita#command#status#complete(arglead, cmdline, cursorpos) abort
  let parser = s:get_parser()
  return parser.complete(a:arglead, a:cmdline, a:cursorpos)
endfunction

call gita#define_variables('command#status', {
      \ 'default_options': {},
      \})
