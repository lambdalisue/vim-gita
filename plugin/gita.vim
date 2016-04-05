if exists('g:loaded_gita')
  finish
endif
let g:loaded_gita = 1

" NOTE: A known minimum requirement is 7.3.1170 : Script local funcref is supported
if v:version < 703 || (v:version == 703 && !has('patch1170'))
  " NOTE: An announced requirement is Vim 7.4
  echohl ErrorMsg | echo 'gita: gita requires Vim 7.4 or later' | echohl None
  finish
endif

let s:is_windows = has('win16') || has('win32') || has('win64')

command! GitaClear :call gita#core#expire()
command! -nargs=* -range -bang
      \ -complete=customlist,gita#command#complete
      \ Gita
      \ call gita#command#command(<q-bang>, [<line1>, <line2>], <q-args>)

augroup gita_internal
  autocmd!
  autocmd FileReadCmd   gita://* nested call gita#content#autocmd('FileReadCmd')
  autocmd FileWriteCmd  gita://* nested call gita#content#autocmd('FileWriteCmd')
  autocmd BufReadCmd    gita:*   nested call gita#content#autocmd('BufReadCmd')
  autocmd BufWriteCmd   gita:*   nested call gita#content#autocmd('BufWriteCmd')
  if !s:is_windows
    " NOTE:
    " autocmd for 'gita:*' is triggerred in Windows so the followings are not
    " required in Windows
    autocmd BufReadCmd    gita:*/* nested call gita#content#autocmd('BufReadCmd')
    autocmd BufWriteCmd   gita:*/* nested call gita#content#autocmd('BufWriteCmd')
  endif
augroup END
