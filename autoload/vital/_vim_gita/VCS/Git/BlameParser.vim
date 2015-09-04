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

let s:funcref_type = type(function("tr"))

function! s:parse(blame, ...) abort " {{{
  let callback = get(a:000, 0, {})
  let is_callback_enabled = !empty(callback)
  if is_callback_enabled
    if !has_key(callback, 'func') || type(callback.func) != s:funcref_type
      throw 'vital: VCS.Git.BlameParser: {callback} require "func" attribute as a funcref'
    endif
    let callback.args = get(callback, 'args', [])
  endif
  let revisions = {}
  let lineinfos = []
  let current_revision = {}
  let current_lineinfo = {}
  let lines = type(a:blame) == type([]) ? a:blame : split(a:blame, '\v\r?\n', 1)
  for line in lines
    let bits = split(line, '\W', 1)
    if len(bits[0]) == 40
      let revision = bits[0]
      let headline = {
            \ 'revision':   revision,
            \ 'linenum': {
            \   'original': bits[1] + 0,
            \   'final':    bits[2] + 0,
            \ },
            \ 'nlines':     get(bits, 3, 0) + 0,
            \}
      if !has_key(revisions, revision)
        let revisions[revision] = {}
      endif
      if !empty(current_lineinfo) && is_callback_enabled
        call call(callback.func, extend([revisions, current_lineinfo], callback.args), callback)
      endif
      let current_revision = revisions[revision]
      let current_lineinfo = headline
      call add(lineinfos, current_lineinfo)
      continue
    elseif len(bits[0]) == 0
      call extend(current_lineinfo, { 'contents': substitute(line, '^\t', '', '') })
      continue
    elseif line ==# 'boundary'
      call extend(current_revision, { 'boundary': 1 })
      continue
    else
      let bits = split(line, ' ', 1)
      let key = substitute(bits[0], '-', '_', 'g')
      let val = join(bits[1:], ' ')
      call extend(current_revision, { key : val })
      continue
    endif
  endfor
  return {
        \ 'revisions': revisions,
        \ 'lineinfos': lineinfos,
        \}
endfunction " }}}
function! s:parse_to_chunks(blame, ...) abort " {{{
  let callback = get(a:000, 0, {})
  let is_callback_enabled = !empty(callback)
  if is_callback_enabled
    if !has_key(callback, 'func') || type(callback.func) != s:funcref_type
      throw 'vital: VCS.Git.BlameParser: {callback} require "func" attribute as a funcref'
    endif
    let callback.args = get(callback, 'args', [])
  endif
  let revisions = {}
  let chunks = []
  let current_revision = {}
  let current_chunk = {}
  let chunk_index = -1
  let lines = type(a:blame) == type([]) ? a:blame : split(a:blame, '\v\r?\n', 1)
  for line in lines
    let bits = split(line, '\W', 1)
    if len(bits[0]) == 40
      if len(bits) < 4
        " nlines column does not exists, mean that this line is in a current chunk
        continue
      endif
      let revision = bits[0]
      let headline = {
            \ 'revision':   revision,
            \ 'linenum': {
            \   'original': bits[1] + 0,
            \   'final':    bits[2] + 0,
            \ },
            \ 'nlines':     get(bits, 3, 0) + 0,
            \}
      if !has_key(revisions, revision)
        let revisions[revision] = {}
      endif
      let current_revision = revisions[revision]
      if chunk_index > -1 && is_callback_enabled
        call call(callback.func, extend([revisions, current_chunk], callback.args), callback)
      endif
      let chunk_index += 1
      let current_chunk = headline
      let current_chunk.index = chunk_index
      let current_chunk.contents = []
      call add(chunks, current_chunk)
      continue
    elseif len(bits[0]) == 0
      call add(current_chunk.contents, substitute(line, '^\t', '', ''))
      continue
    elseif line ==# 'boundary'
      call extend(current_revision, { 'boundary': 1 })
      continue
    else
      let bits = split(line, ' ', 1)
      let key = substitute(bits[0], '-', '_', 'g')
      let val = join(bits[1:], ' ')
      call extend(current_revision, { key : val })
      continue
    endif
  endfor
  if chunk_index > -1 && is_callback_enabled
    call call(callback.func, extend([revisions, current_chunk], callback.args), callback)
  endif
  return {
        \ 'revisions': revisions,
        \ 'chunks': chunks,
        \}
endfunction " }}}

let &cpo = s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
