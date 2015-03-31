"******************************************************************************
" vim-gita arguments/diff
"
" Author:   Alisue <lambdalisue@hashnote.net>
" URL:      http://hashnote.net/
" License:  MIT license
" (C) 2015, Alisue, hashnote.net
"******************************************************************************
let s:save_cpo = &cpo
set cpo&vim

let s:ArgumentParser = gita#util#import('ArgumentParser')

function! s:get_parser() abort " {{{
  if !exists('s:parser')
    let s:parser = s:ArgumentParser.new({
          \   'name': 'Show changes between commits, commit and working tree, etc',
          \   'validate_unknown': 0,
          \ })
  endif
  return s:parser
endfunction " }}}

function! gita#arguments#diff#parse(bang, range, ...) abort " {{{
  let cmdline = get(a:000, 0, '')
  let settings = get(a:000, 1, {})
  let parser = s:get_parser()
  let args = [a:bang, a:range, cmdline, settings]
  let opts = call(parser.parse, args, parser)
  return opts
endfunction " }}}
function! gita#arguments#diff#complete(arglead, cmdline, cursorpos) abort " {{{
  let parser = s:get_parser()
  let args = [a:arglead, a:cmdline, a:cursorpos]
  let complete = call(parser.complete, args, parser)
  return complete
endfunction " }}}


let &cpo = s:save_cpo
unlet s:save_cpo
"vim: sts=2 sw=2 smarttab et ai textwidth=0 fdm=marker
