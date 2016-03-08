if exists('b:current_syntax')
  finish
endif
let b:current_syntax = 'gita-ls-tree'

highlight default link GitaComment Comment

syntax clear
syntax match GitaComment /\%^.*$/
