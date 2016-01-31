let s:save_cpo = &cpo
set cpo&vim

command! -nargs=? -range -bang
      \ -complete=customlist,gita#command#complete
      \ Gita
      \ :call gita#command#command(<q-bang>, [<line1>, <line2>], <f-args>)

" NOTE:
" To use gf mapping on gita://, isfname requires to contain ':'
augroup vim_gita_internal_read_file
  autocmd!
  autocmd BufReadCmd  gita://* call gita#autocmd#call('BufReadCmd')
  autocmd FileReadCmd gita://* call gita#autocmd#call('FileReadCmd')
  try
    autocmd SourceCmd gita://* call gita#autocmd#call('SourceCmd')
  catch /-Vim\%((\a\+)\)\=E216/
    autocmd SourcePre gita://* call gita#autocmd#call('SourceCmd')
  endtry
augroup END

augroup vim_gita_internal_status_modified
  autocmd!
  autocmd BufWritePre * call gita#autocmd#call('BufWritePre')
  autocmd BufWritePost * call gita#autocmd#call('BufWritePost')
augroup END


let &cpo = s:save_cpo
unlet! s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
