let s:save_cpo = &cpo
set cpo&vim

let s:V = gista#vital()

function! hita#option#assign_commit(options) abort
  if has_key(a:options, 'commit')
    return
  endif
  let commit = hita#meta#get('commit')
  if !empty(commit)
    let a:options.commit = commit
  endif
endfunction
function! hita#option#assign_filename(options) abort
  if has_key(a:options, 'filename')
    return
  endif
  let filename = hita#meta#get('filename')
  if !empty(filename)
    let a:options.filename = filename
  endif
endfunction


let &cpo = s:save_cpo
unlet! s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
