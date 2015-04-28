let s:save_cpo = &cpo
set cpo&vim

let s:Path = gita#util#import('System.Filepath')
let s:ArgumentParser = gita#util#import('ArgumentParser')

function! gita#argument#status#get_parser() abort " {{{
  if !exists('s:parser')
    let s:parser = s:ArgumentParser.new({
          \ 'name': 'Show the working tree status in Gita interface',
          \})
    let types = s:ArgumentParser.types
    call s:parser.add_argument(
          \ '--untracked-files',
          \ 'show untracked files, optional modes: all, normal, no. (Default: all)', {
          \   'alias': 'u',
          \   'choices': ['all', 'normal', 'no'],
          \   'default': 'all',
          \ })
    call s:parser.add_argument(
          \ '--ignored',
          \ 'show ignored files', {
          \ })
    call s:parser.add_argument(
          \ '--ignore-submodules',
          \ 'ignore changes to submodules, optional when: all, dirty, untracked (Default: all)', {
          \   'choices': ['all', 'dirty', 'untracked'],
          \   'default': 'all',
          \ })
  endif
  return s:parser
endfunction " }}}

let &cpo = s:save_cpo
unlet s:save_cpo
"vim: sts=2 sw=2 smarttab et ai textwidth=0 fdm=marker
