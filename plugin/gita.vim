if exists('g:loaded_gita')
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
  autocmd BufReadCmd    gita://* nested call gita#autocmd#call('BufReadCmd')
  autocmd BufWriteCmd   gita://* nested call gita#autocmd#call('BufWriteCmd')
  autocmd FileReadCmd   gita://* nested call gita#autocmd#call('FileReadCmd')
  autocmd FileWriteCmd  gita://* nested call gita#autocmd#call('FileWriteCmd')
  autocmd BufReadCmd    gita:*   nested call gita#autocmd#call('BufReadCmd')
  autocmd BufWriteCmd   gita:*   nested call gita#autocmd#call('BufWriteCmd')
  autocmd BufReadCmd    gita:*/* nested call gita#autocmd#call('BufReadCmd')
  autocmd BufWriteCmd   gita:*/* nested call gita#autocmd#call('BufWriteCmd')
augroup END
