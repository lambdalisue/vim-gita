if exists('b:current_syntax')
  finish
endif
let b:current_syntax = 'gita-ls-tree'

syntax clear
call gita#command#ui#ls_tree#define_highlights()
call gita#command#ui#ls_tree#define_syntax()
