if exists('b:current_syntax')
  finish
endif
let b:current_syntax = 'gita-grep'

syntax clear
call gita#command#grep#define_highlights()
call gita#command#grep#define_syntax()
