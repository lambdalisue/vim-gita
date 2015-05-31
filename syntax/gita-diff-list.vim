if exists('b:current_syntax')
  finish
endif

let s:save_cpo = &cpo
set cpo&vim

syntax clear
call gita#features#diff#define_highlights()
call gita#features#diff#define_syntax()

let b:current_syntax = "gita-diff-list"
let &cpo = s:save_cpo
"vim: sts=2 sw=2 smarttab et ai textwidth=0 fdm=marker
