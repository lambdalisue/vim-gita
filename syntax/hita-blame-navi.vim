if exists('b:current_syntax')
  finish
endif
let b:current_syntax = 'hita-blame-navi'

syntax clear
call hita#command#blame#navi#define_highlights()
call hita#command#blame#navi#define_syntax()

