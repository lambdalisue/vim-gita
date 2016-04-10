let s:V = gita#vital()
let s:ArgumentParser = s:V.import('ArgumentParser')

function! s:get_parser() abort
  if !exists('s:parser') || g:gita#develop
    let s:parser = s:ArgumentParser.new({
          \ 'name': 'Gita commit',
          \ 'description': 'Record changes to the repository',
          \ 'complete_threshold': g:gita#complete_threshold,
          \})
    call s:parser.add_argument(
          \ '--reset-author',
          \ 'reset author for commit',
          \)
    call s:parser.add_argument(
          \ '--author',
          \ 'override author for commit', {
          \   'type': s:ArgumentParser.types.value,
          \})
    call s:parser.add_argument(
          \ '--date',
          \ 'override date for commit', {
          \   'type': s:ArgumentParser.types.value,
          \})
    call s:parser.add_argument(
          \ '--gpg-sign', '-S',
          \ 'GPG sign commit', {
          \   'type': s:ArgumentParser.types.any,
          \   'conflicts': ['no-gpg-sign'],
          \})
    call s:parser.add_argument(
          \ '--no-gpg-sign',
          \ 'no GPG sign commit', {
          \   'conflicts': ['gpg-sign'],
          \})
    call s:parser.add_argument(
          \ '--amend',
          \ 'amend previous commit',
          \)
    call s:parser.add_argument(
          \ '--allow-empty',
          \ 'allow an empty commit',
          \)
    call s:parser.add_argument(
          \ '--allow-empty-message',
          \ 'allow an empty commit message',
          \)
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

function! gita#command#commit#command(bang, range, args) abort
  let parser  = s:get_parser()
  let options = parser.parse(a:bang, a:range, a:args)
  if empty(options)
    return
  endif
  let options = extend(
        \ copy(g:gita#command#commit#default_options),
        \ options
        \)
  call gita#util#option#assign_opener(options)
  call gita#content#commit#open(options)
endfunction

function! gita#command#commit#complete(arglead, cmdline, cursorpos) abort
  let parser = s:get_parser()
  return parser.complete(a:arglead, a:cmdline, a:cursorpos)
endfunction

call gita#define_variables('command#commit', {
      \ 'default_options': {},
      \})
