if exists('b:current_syntax')
  finish
endif
let b:current_syntax = 'gita-commit'

syntax clear
call gita#command#ui#commit#define_highlights()
call gita#command#ui#commit#define_syntax()
