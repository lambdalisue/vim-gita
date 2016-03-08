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
