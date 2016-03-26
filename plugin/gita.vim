if exists('g:loaded_gita')
  finish
endif
let g:loaded_gita = 1

command! GitaClear :call gita#core#expire()
command! -nargs=* -range -bang
      \ -complete=customlist,gita#command#complete
      \ Gita
      \ call gita#command#command(<q-bang>, [<line1>, <line2>], <q-args>)

augroup vim_gita_internal
  autocmd!
  autocmd FileReadCmd   gita://* nested call gita#content#autocmd('FileReadCmd')
  autocmd FileWriteCmd  gita://* nested call gita#content#autocmd('FileWriteCmd')
  autocmd BufReadCmd    gita:*   nested call gita#content#autocmd('BufReadCmd')
  autocmd BufWriteCmd   gita:*   nested call gita#content#autocmd('BufWriteCmd')
  autocmd BufReadCmd    gita:*/* nested call gita#content#autocmd('BufReadCmd')
  autocmd BufWriteCmd   gita:*/* nested call gita#content#autocmd('BufWriteCmd')
augroup END
