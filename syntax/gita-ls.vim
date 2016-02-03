if exists('b:current_syntax')
  finish
endif
let b:current_syntax = 'gita-ls'

syntax clear
call gita#command#ls#define_highlights()
call gita#command#ls#define_syntax()

