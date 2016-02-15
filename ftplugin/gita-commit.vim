if exists('b:did_ftplugin')
  finish
endif
let b:did_ftplugin = 1

" Users can override the following with user's ftplugin/gita-commit.vim
setlocal winfixheight
setlocal cursorline
setlocal nolist nospell
setlocal nowrap nofoldenable
setlocal foldcolumn=0 colorcolumn=0

function! s:keep_height() abort
  resize 10
endfunction
augroup vim_gita_commit_window_size
  autocmd! * <buffer>
  autocmd BufEnter <buffer> call s:keep_height()
augroup END
