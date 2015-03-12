"******************************************************************************
" vim-gita command options
"
" Author:   Alisue <lambdalisue@hashnote.net>
" URL:      http://hashnote.net/
" License:  MIT license
" (C) 2015, Alisue, hashnote.net
"******************************************************************************
let s:save_cpo = &cpo
set cpo&vim


function! s:get_parser() " {{{
  if !exists('s:parser') || 1
    let s:parser = gita#utils#vital#ArgumentParser()
    call s:parser.add_argument(
          \ '--status',
          \ 'Show current status', {
          \   'kind': s:parser.kinds.any,
          \   'conflict_with': 'command',
          \})
  endif
  return s:parser
endfunction " }}}


function! gita#arguments#parse(...) abort " {{{
  let parser = s:get_parser()
  return call(parser.parse, a:000, parser)
endfunction " }}}
function! gita#arguments#complete(...) abort " {{{
  let parser = s:get_parser()
  return call(parser.complete, a:000, parser)
endfunction " }}}


let &cpo = s:save_cpo
unlet s:save_cpo
"vim: sts=2 sw=2 smarttab et ai textwidth=0 fdm=marker
