if exists('b:current_syntax')
  finish
endif
let b:current_syntax = 'gita-ls-files'

syntax clear
call gita#command#ui#ls_files#define_highlights()
call gita#command#ui#ls_files#define_syntax()
