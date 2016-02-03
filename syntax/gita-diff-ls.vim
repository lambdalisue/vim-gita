if exists('b:current_syntax')
  finish
endif
let b:current_syntax = 'gita-diff-ls'

syntax clear
call gita#command#diff_ls#define_highlights()
call gita#command#diff_ls#define_syntax()
