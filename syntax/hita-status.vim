if exists('b:current_syntax')
  finish
endif
let b:current_syntax = 'gita-status'

syntax clear
call gita#command#status#define_highlights()
call gita#command#status#define_syntax()
