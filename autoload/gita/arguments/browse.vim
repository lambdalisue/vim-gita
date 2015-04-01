"******************************************************************************
" vim-gita arguments/browse
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
          \   'name': 'Get a remote url of files and open/echo/yank the url',
          \   'validate_unknown': 0,
          \ })
    call s:parser.add_argument(
          \ '--open',
          \ 'Open a url', {
          \   'conflict_with': 'action',
          \ })
    call s:parser.add_argument(
          \ '--echo',
          \ 'Echo a url', {
          \   'conflict_with': 'action',
          \ })
    call s:parser.add_argument(
          \ '--yank',
          \ 'Yank a url', {
          \   'conflict_with': 'action',
          \ })
    call s:parser.add_argument(
          \ '--exact', '-e',
          \ 'Use a url of exact version of the local file', {
          \ })
    function! s:parser.hooks.pre_validation(args) abort " {{{
      let args = copy(a:args)
      if !self.has_conflict_with('open', args)
        let args.open = self.true
      endif
      return args
    endfunction " }}}
  endif
  return s:parser
endfunction " }}}

function! gita#arguments#browse#parse(bang, range, ...) abort " {{{
  let cmdline = get(a:000, 0, '')
  let settings = get(a:000, 1, {})
  let parser = s:get_parser()
  let args = [a:bang, a:range, cmdline, settings]
  let opts = call(parser.parse, args, parser)
  let opts.filenames = get(opts, '__unknown__', [])
  if empty(opts.filenames)
    let opts.filenames = [expand('%')]
  endif
  return opts
endfunction " }}}
function! gita#arguments#browse#complete(arglead, cmdline, cursorpos) abort " {{{
  let completers = s:ArgumentParser.get_completers()
  return completers.file(a:arglead, a:cmdline, a:cursorpos, {})
endfunction " }}}


let &cpo = s:save_cpo
unlet s:save_cpo
"vim: sts=2 sw=2 smarttab et ai textwidth=0 fdm=marker

