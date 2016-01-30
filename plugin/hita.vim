let s:save_cpo = &cpo
set cpo&vim

command! -nargs=? -range=% -bang
      \ -complete=customlist,hita#command#complete
      \ Hita
      \ :call hita#command#command(<q-bang>, [<line1>, <line2>], <f-args>)

" NOTE:
" To use gf mapping on hita://, isfname requires to contain ':'
augroup vim_hita_internal_read_file
  autocmd!
  autocmd BufReadCmd  hita://* call hita#autocmd#call('BufReadCmd')
  autocmd FileReadCmd hita://* call hita#autocmd#call('FileReadCmd')
  try
    autocmd SourceCmd hita://* call hita#autocmd#call('SourceCmd')
  catch /-Vim\%((\a\+)\)\=E216/
    autocmd SourcePre hita://* call hita#autocmd#call('SourceCmd')
  endtry
augroup END

let &cpo = s:save_cpo
unlet! s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
