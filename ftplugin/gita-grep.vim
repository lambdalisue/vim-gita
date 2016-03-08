if exists('b:did_ftplugin')
  finish
endif
let b:did_ftplugin = 1

setlocal winfixheight
setlocal cursorline
setlocal nolist nospell
setlocal nowrap nofoldenable
setlocal foldcolumn=0 colorcolumn=0

function! s:keep_height() abort
  if winnr('$') > 1
    wincmd J
    resize 10
  endif
endfunction
augroup vim_gita_window_size
  autocmd! * <buffer>
  autocmd BufEnter <buffer> call s:keep_height()
augroup END

