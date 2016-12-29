if exists('b:did_ftplugin')
  finish
endif
let b:did_ftplugin = 1

setlocal winfixheight
if &cursorline
  setlocal cursorline
endif
if !&spell
  setlocal nospell
endif
setlocal nolist 
setlocal nowrap nofoldenable
setlocal foldcolumn=0 colorcolumn=0
