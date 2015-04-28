let s:save_cpo = &cpo
set cpo&vim

let s:ArgumentParser = gita#util#import('ArgumentParser')

function! gita#argument#browse#get_parser() abort " {{{
  if !exists('s:parser')
    let s:parser = s:ArgumentParser.new({
          \   'name': 'Get a remote url of files and open/echo/yank the url',
          \ })
    call s:parser.add_argument(
          \ 'action',
          \ 'An action of the command', {
          \   'choices': ['open', 'echo', 'yank'],
          \ })
    call s:parser.add_argument(
          \ '--master',
          \ 'Use a url of master version of the local file', {
          \   'alias': 'm',
          \ })
    call s:parser.add_argument(
          \ '--exact',
          \ 'Use a url of exact version of the local file', {
          \   'alias': 'e',
          \ })
  endif
  return s:parser
endfunction " }}}

let &cpo = s:save_cpo
unlet s:save_cpo
"vim: sts=2 sw=2 smarttab et ai textwidth=0 fdm=marker

