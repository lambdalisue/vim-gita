let s:save_cpo = &cpo
set cpo&vim

let s:Path = gita#util#import('System.Filepath')
let s:ArgumentParser = gita#util#import('ArgumentParser')

function! gita#argument#commit#get_parser() abort " {{{
  if !exists('s:parser')
    let s:parser = s:ArgumentParser.new({
          \ 'name': 'Record changes to the repository via Gita interface',
          \})
    let types = s:ArgumentParser.types
    call s:parser.add_argument(
          \ '--all',
          \ 'commit all changed files', {
          \   'alias': 'a',
          \ })
    call s:parser.add_argument(
          \ '--include',
          \ 'add specified files to index for commit', {
          \   'alias': 'i',
          \   'type': types.value,
          \ })
    call s:parser.add_argument(
          \ '--reset-author',
          \ 'the commit is authored by me now (used with -C/-c/--amend)', {
          \ })
    call s:parser.add_argument(
          \ '--amend',
          \ 'amend previous commit', {
          \ })
    call s:parser.add_argument(
          \ '--untracked-files',
          \ 'show untracked files, optional modes: all, normal, no. (Default: all)', {
          \   'alias': 'u',
          \   'choices': ['all', 'normal', 'no'],
          \   'default': 'all',
          \ })
  endif
  return s:parser
endfunction " }}}


let &cpo = s:save_cpo
unlet s:save_cpo
"vim: sts=2 sw=2 smarttab et ai textwidth=0 fdm=marker

