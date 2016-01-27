if exists('b:current_syntax')
  finish
endif
let b:current_syntax = 'hita-status'

syntax clear
call hita#command#status#define_highlights()
call hita#command#status#define_syntax()
