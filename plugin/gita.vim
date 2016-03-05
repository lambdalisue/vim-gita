if exists('g:loaded_gita') && get(g:, 'gita#develop')
  finish
endif
let g:loaded_gita = 1

command! GitaClear :call gita#clear()
command! -nargs=? -range -bang
      \ -complete=customlist,gita#command#complete
      \ Gita
      \ :call gita#command#command(<q-bang>, [<line1>, <line2>], <f-args>)

augroup vim_gita_internal_autocmd
  autocmd!
  autocmd BufReadCmd   gita://* call gita#autocmd#call('BufReadCmd')
  autocmd FileReadCmd  gita://* call gita#autocmd#call('FileReadCmd')
  autocmd SourceCmd    gita://* call gita#autocmd#call('SourceCmd')
  " to check if the content in git repository is updated
  autocmd BufWritePre  *        call gita#autocmd#call('BufWritePre')
  autocmd BufWritePost *        call gita#autocmd#call('BufWritePost')
augroup END
