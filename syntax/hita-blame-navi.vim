if exists('b:current_syntax')
  finish
endif
let b:current_syntax = 'gita-blame-navi'

syntax clear
call gita#command#blame#navi#define_highlights()
call gita#command#blame#navi#define_syntax()

