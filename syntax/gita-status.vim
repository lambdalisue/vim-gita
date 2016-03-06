if exists('b:current_syntax')
  finish
endif
let b:current_syntax = 'gita-status'

syntax clear
call gita#command#ui#status#define_highlights()
call gita#command#ui#status#define_syntax()
