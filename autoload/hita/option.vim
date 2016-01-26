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
  let filename = hita#core#expand('%')
  if !empty(filename)
    let a:options.filename = filename
  endif
endfunction
