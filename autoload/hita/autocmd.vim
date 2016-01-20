let s:save_cpo = &cpo
set cpo&vim

function! s:on_SourceCmd(info) abort
  let content = getbufline(expand('<afile>'), 1, '$')
  try
    let tempfile = tempname()
    call writefile(content, tempfile)
    execute printf('source %s', fnameescape(tempfile))
  finally
    if filereadable(tempfile)
      call delete(tempfile)
    endif
  endtry
endfunction
function! s:on_BufReadCmd(info) abort
  let content_type = get(a:info, 'content_type', '')
  if content_type ==# 'raw'
    call hita#command#open#edit({
          \ 'commit': a:info.commit,
          \ 'filename': a:info.filename,
          \ 'force': v:cmdbang,
          \})
  else
    call hita#throw(printf(
          \ 'Unknown content_type "%s" is specified',
          \ content_type,
          \))
  endif
endfunction
function! s:on_FileReadCmd(info) abort
  let content_type = get(a:info, 'content_type', '')
  if content_type ==# 'raw'
    call hita#command#open#read({
          \ 'gistid': a:info.gistid,
          \ 'filename': a:info.filename,
          \ 'force': v:cmdbang,
          \})
  else
    call hita#throw(printf(
          \ 'Unknown content_type "%s" is specified',
          \ content_type,
          \))
  endif
endfunction

function! hita#autocmd#call(name) abort
  let fname = 's:on_' . a:name
  if !exists('*' . fname)
    call hita#throw(printf(
          \ 'No autocmd function "%s" is found.', fname
          \))
  endif
  let info = hita#autocmd#parse_filename(expand('<afile>'))
  call call(fname, [info])
endfunction

let s:schemes = [
      \ ['^hita://\([^:]\+\):\([^:]*\):\(.*\)$', {
      \   'content_type': 1,
      \   'commit': 2,
      \   'filename': 3,
      \ }],
      \ ['^hita://\([^:]*\):\(.*\)$', {
      \   'content_type': 'raw',
      \   'commit': 1,
      \   'filename': 2,
      \ }],
      \]
function! hita#autocmd#parse_filename(filename) abort
  for scheme in s:schemes
    if a:filename !~# scheme[0]
      continue
    endif
    let m = matchlist(a:filename, scheme[0])
    let o = {}
    for [key, value] in items(scheme[1])
      if type(value) == type(0)
        let o[key] = m[value]
      else
        let o[key] = value
      endif
      unlet value
    endfor
    return o
  endfor
  return {}
endfunction

let &cpo = s:save_cpo
unlet! s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
