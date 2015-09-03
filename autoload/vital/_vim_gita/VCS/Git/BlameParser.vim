"******************************************************************************
" Git blame (--porcelain) parser
"
" Author:   Alisue <lambdalisue@hashnote.net>
" URL:      http://hashnote.net/
" License:  MIT license
"
" (C) 2015, Alisue, hashnote.net
"******************************************************************************
let s:save_cpo = &cpo
set cpo&vim


let s:HEADLINE_PATTERN = '\v^([0-9a-fA-F]{40})\s(\d+)\s(\d+)%(\s(\d+))?$'
let s:INFOLINE_PATTERN = '\v^([^ 	]+)\s(.*)$'
let s:CONTENTS_PATTERN = '\v^\t\zs(.*)$'

function! s:_vital_loaded(V) abort
  let s:D = a:V.import('Data.Dict')
endfunction
function! s:_vital_created(module) abort
  let const = {}
  let const.HEADLINE_PATTERN = s:HEADLINE_PATTERN
  let const.INFOLINE_PATTERN = s:INFOLINE_PATTERN
  let const.CONTENTS_PATTERN = s:CONTENTS_PATTERN
  lockvar const
  call extend(a:module, const)
endfunction

function! s:parse_headline(line) abort " {{{
  let m = matchlist(a:line, s:HEADLINE_PATTERN)
  return {
        \ 'revision':   m[1],
        \ 'linenum': {
        \   'original': m[2] + 0,
        \   'final':    m[3] + 0,
        \ },
        \ 'nlines':     m[4] + 0,
        \}
endfunction " }}}
function! s:parse_infoline(line) abort " {{{
  let m = matchlist(a:line, s:INFOLINE_PATTERN)
  return {
        \ substitute(m[1], '-', '_', 'g'): m[2],
        \}
endfunction " }}}
function! s:parse_contents(line, ...) abort " {{{
  let m = matchlist(a:line, s:CONTENTS_PATTERN)
  return m[1]
endfunction " }}}

function! s:parse(blame, ...) abort " {{{
  let o = get(a:000, 0, {})
  let revisions = {}
  let lineinfos = []
  let current_revision = {}
  let current_lineinfo = {}
  for line in split(a:blame, '\v\r?\n')
    if line =~# s:HEADLINE_PATTERN
      let headline = s:parse_headline(line)
      if !has_key(revisions, headline.revision)
        let revisions[headline.revision] = {}
      endif
      let current_revision = revisions[headline.revision]
      let current_lineinfo = headline
      call add(lineinfos, headline)
      continue
    elseif line =~# s:INFOLINE_PATTERN
      call extend(current_revision, s:parse_infoline(line))
      continue
    elseif line =~# s:CONTENTS_PATTERN
      call extend(current_lineinfo, { 'contents': s:parse_contents(line) })
      continue
    elseif line ==# 'boundary'
      call extend(current_revision, { 'boundary': 1 })
      continue
    elseif get(o, 'fail_silently')
      continue
    else
      throw printf(
            \ 'vital: VCS.Git.BlameParser: "%s" could not be parsed.',
            \ line,
            \)
    endif
  endfor
  return {
        \ 'revisions': revisions,
        \ 'lineinfos': lineinfos,
        \}
endfunction " }}}


let &cpo = s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
