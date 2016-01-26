function! s:parse_mapping(raw) abort
  " Note:
  " :help map-listing
  let m = matchlist(a:raw, '\(...\)\s*\(\S\+\)\s*\([*&@]\{,3}\)\s*\(\S\+\)')
  return m[1 : 4]
endfunction
function! s:filter_mappings(rhs, ...) abort
  let options = extend({
        \ 'noremap': 0,
        \ 'buffer': 0,
        \}, get(a:000, 0, {})
        \)
  let flag = join([
        \ options.noremap ? '*' : '',
        \ options.buffer ? '@' : '',
        \], '')
  let rhs = flag . a:rhs . '\S*$'
  try
    redir => content
    silent execute 'map'
  finally
    redir END
  endtry
  return map(filter(
        \ split(content, "\r\\?\n"),
        \ 'v:val =~# rhs'
        \), 's:parse_mapping(v:val)'
        \)
endfunction
function! s:compare(i1, i2) abort
  return a:i1[1] == a:i2[1] ? 0 : a:i1[1] > a:i2[1] ? 1 : -1
endfunction

" @vimlint(EVL102, 1, l:mode)
" @vimlint(EVL102, 1, l:flag)
function! hita#util#mapping#help(table) abort
  let mappings = s:filter_mappings('<Plug>(hita-', {
        \ 'noremap': 0,
        \ 'buffer': 1,
        \})
  let longest = 0
  let precursors = []
  for [mode, lhs, flag, rhs] in mappings
    if len(lhs) > longest
      let longest = len(lhs)
    endi
    call add(precursors, [lhs, get(a:table, rhs, rhs)])
  endfor
  let contents = []
  for [lhs, rhs] in sort(precursors, 's:compare')
    call add(contents, printf(
          \ printf('%%-%ds : %%s', longest),
          \ lhs, rhs
          \))
  endfor
  return contents
endfunction
" @vimlint(EVL102, 0, l:mode)
" @vimlint(EVL102, 0, l:flag)
