if exists('b:current_syntax')
  finish
endif
let b:current_syntax = 'gita-ls-files'

highlight default link GitaComment Comment

syntax clear
syntax match GitaComment /\%^.*$/
