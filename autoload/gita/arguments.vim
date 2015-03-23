"******************************************************************************
" vim-gita arguments
"
" Author:   Alisue <lambdalisue@hashnote.net>
" URL:      http://hashnote.net/
" License:  MIT license
" (C) 2015, Alisue, hashnote.net
"******************************************************************************
let s:save_cpo = &cpo
set cpo&vim

let s:Path = gita#util#import('System.Filepath')
let s:ArgumentParser = gita#util#import('ArgumentParser')

function! gita#arguments#parse(bang, range, ...) abort " {{{
  let cmdline = get(a:000, 0, '')
  let args = split(cmdline)
  let name = args[0]
  let cmdname = printf('gita#arguments#%s#parse', name)
  if exists(cmdname)
    let cmdline = len(args) > 1 ? join(args[1:]) : ''
    let opts = call(cmdname, [a:bang, a:range, cmdline])
  else
    let opts = {'args': s:ArgumentParser.shellwords(cmdline)}
  endif
  let opts._name = name
  return opts
endfunction " }}}
function! gita#arguments#complete(arglead, cmdline, cursorpos) abort " {{{
  let args = split(a:cmdline)
  let name = args[0]
  let cmdname = printf('gita#arguments#%s#complete', name)
  if exists(cmdname)
    let cmdline = len(args) > 1 ? join(args[1:]) : ''
    let complete = call(cmdname, [a:arglead, cmdline, a:cursorpos])
  else
    let complete = []
  endif
  return complete
endfunction
" }}}


let &cpo = s:save_cpo
unlet s:save_cpo
"vim: sts=2 sw=2 smarttab et ai textwidth=0 fdm=marker
