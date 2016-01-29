let s:V = gista#vital()

function! hita#option#init(content_type, options, ...) abort
  let options = deepcopy(a:options)
  if !empty(a:content_type)
        \ && hita#get_meta('content_type', '') ==# a:content_type
    call extend(options, hita#get_meta('options', {}), 'keep')
  endif
  call extend(options, get(a:000, 0, {}), 'keep')
  return options
endfunction

function! hita#option#assign_commit(options) abort
  if has_key(a:options, 'commit')
    return
  endif
  let commit = hita#get_meta('commit')
  if !empty(commit)
    let a:options.commit = commit
  endif
endfunction
function! hita#option#assign_filename(options) abort
  if has_key(a:options, 'filename')
    return
  endif
  " NOTE:
  " hita#expand() always return a real absolute path or ''
  let filename = hita#expand('%')
  if !empty(filename)
    let a:options.filename = filename
  endif
endfunction
