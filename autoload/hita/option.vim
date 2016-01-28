let s:V = gista#vital()

function! hita#option#assign_commit(options) abort
  if has_key(a:options, 'commit')
    return
  endif
  let commit = hita#core#get_meta('commit')
  if !empty(commit)
    let a:options.commit = commit
  endif
endfunction
function! hita#option#assign_filename(options) abort
  if has_key(a:options, 'filename')
    return
  endif
  " NOTE:
  " hita#core#expand() always return a real absolute path or ''
  let filename = hita#core#expand('%')
  if !empty(filename)
    let a:options.filename = filename
  endif
endfunction
function! hita#option#assign_options(options, content_type) abort
  if hita#core#get_meta('content_type', '') ==# a:content_type
    call extend(a:options, hita#core#get_meta('options', {}), 'keep')
  endif
endfunction
