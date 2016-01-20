let s:save_cpo = &cpo
set cpo&vim

let s:V = hita#vital()
let s:Path = s:V.import('System.Filepath')

function! hita#variable#get_valid_commit(commit) abort
  return a:commit
endfunction
function! hita#variable#get_valid_filename(filename) abort
  let filename = s:Path.abspath(a:filename)
  return filename
endfunction

let &cpo = s:save_cpo
unlet! s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
