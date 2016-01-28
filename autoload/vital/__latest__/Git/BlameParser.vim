function! s:_vital_loaded(V) abort
  let s:Prelude = a:V.import('Prelude')
endfunction
function! s:_vital_depends() abort
  return ['Prelude']
endfunction
function! s:_vital_created(module) abort
endfunction

function! s:_throw(msg) abort
  throw 'vital: Git.BlameParser: ' . a:msg
endfunction

function! s:parse(blame, ...) abort
  let Callback = get(a:000, 0, 0)
  let is_callable = s:Prelude.is_funcref(Callback)
  let revisions = {}
  let lineinfos = []
  let current_revision = {}
  let current_lineinfo = {}
  let lines = s:Prelude.is_string(a:blame)
        \ ? split(a:blame, '\r\?\n', 1)
        \ : a:blame
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
      if !empty(current_lineinfo) && is_callable
        call call(Callback, [revisions, current_lineinfo])
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
  let Callback = get(a:000, 0, 0)
  let is_callable = s:Prelude.is_funcref(Callback)
  let revisions = {}
  let chunks = []
  let current_revision = {}
  let current_chunk = {}
  let chunk_index = -1
  let lines = s:Prelude.is_string(a:blame)
        \ ? split(a:blame, '\r\?\n', 1)
        \ : a:blame
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
      if chunk_index > -1 && is_callable
        call call(Callback, [revisions, current_chunk])
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
    if chunk_index > -1 && is_callable
      call call(Callback, [revisions, current_chunk])
    endif
  return {
        \ 'revisions': revisions,
        \ 'chunks': chunks,
        \}
endfunction " }}}
