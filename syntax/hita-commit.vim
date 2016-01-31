if exists('b:current_syntax')
  finish
endif
let b:current_syntax = 'gita-commit'

syntax clear
call gita#command#commit#define_highlights()
call gita#command#commit#define_syntax()

