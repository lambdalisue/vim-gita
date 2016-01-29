if exists('b:current_syntax')
  finish
endif
let b:current_syntax = 'hita-commit'

syntax clear
call hita#command#commit#define_highlights()
call hita#command#commit#define_syntax()

