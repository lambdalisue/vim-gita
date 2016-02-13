if exists('b:current_syntax')
  finish
endif
let b:current_syntax = 'gita-branch'

syntax clear
call gita#command#branch#define_highlights()
call gita#command#branch#define_syntax()

