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

function! s:_vital_loaded(V) dict abort
  let s:D = a:V.import('Data.Dict')
  let s:const = {}
  let s:const.HEADLINE_PATTERN = s:HEADLINE_PATTERN
  let s:const.INFOLINE_PATTERN = s:INFOLINE_PATTERN
  let s:const.CONTENTS_PATTERN = s:CONTENTS_PATTERN
  lockvar s:const
  call extend(self, s:const)
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
  let previous_chunk = {}
  let current_chunk = { 'revision': '' }
  let chunks = []
  for line in split(a:blame, '\v\r?\n')
    if line =~# s:HEADLINE_PATTERN
      let chunk = s:parse_headline(line)
      let chunk.contents = []
      if chunk.revision !=# current_chunk.revision
        call add(chunks, chunk)
        let previous_chunk = current_chunk
        let current_chunk = chunk
      endif
      continue
    elseif line =~# s:INFOLINE_PATTERN
      call extend(current_chunk, s:parse_infoline(line))
      continue
    elseif line =~# s:CONTENTS_PATTERN
      if !has_key(current_chunk, 'filename')
        " hit CONTENTS line without parsing INFO line, mean that the INFO of
        " current chunk is equal to the previous one
        call extend(current_chunk, s:D.omit(previous_chunk, keys(current_chunk)))
      endif
      call add(current_chunk.contents, s:parse_contents(line))
      continue
    elseif line ==# 'boundary'
      " http://git.kaarsemaker.net/git/commit/b11121d9e330c40f5d089636f176d089e5bb1885/
      let current_chunk.boundary = 1
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
  return chunks
endfunction " }}}


let &cpo = s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
