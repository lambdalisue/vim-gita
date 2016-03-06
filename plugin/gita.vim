if exists('g:loaded_gita') && get(g:, 'gita#develop')
  finish
endif
let g:loaded_gita = 1

command! GitaClear :call gita#core#expire()
command! -nargs=? -range -bang
      \ -complete=customlist,gita#command#complete
      \ Gita
      \ :call gita#command#command(<q-bang>, [<line1>, <line2>], <f-args>)

augroup vim_gita_internal_autocmd
  autocmd!
  autocmd SourceCmd     gita://* call gita#autocmd#call('SourceCmd')
  autocmd BufReadCmd    gita://* nested call gita#autocmd#call('BufReadCmd')
  autocmd BufWriteCmd   gita://* nested call gita#autocmd#call('BufWriteCmd')
  autocmd FileReadCmd   gita://* nested call gita#autocmd#call('FileReadCmd')
  autocmd FileWriteCmd  gita://* nested call gita#autocmd#call('FileWriteCmd')
  autocmd BufReadCmd    gita:*   nested call gita#autocmd#call('BufReadCmd')
  autocmd BufWriteCmd   gita:*   nested call gita#autocmd#call('BufWriteCmd')
  autocmd BufReadCmd    gita:*/* nested call gita#autocmd#call('BufReadCmd')
  autocmd BufWriteCmd   gita:*/* nested call gita#autocmd#call('BufWriteCmd')
  " to check if the content in git repository is updated
  autocmd BufWritePre  * call gita#autocmd#call('BufWritePre')
  autocmd BufWritePost * call gita#autocmd#call('BufWritePost')
  " to update status window
  autocmd User GitaStatusModified nested call gita#autocmd#call('GitaStatusModified')
augroup END
