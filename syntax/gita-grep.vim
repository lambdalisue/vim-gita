if exists('b:current_syntax')
  finish
endif
let b:current_syntax = 'gita-grep'

highlight default link GitaComment    Comment
highlight default link GitaKeyword    Keyword

syntax clear
syntax match GitaComment    /\%^.*$/
syntax match GitaMatchFilename /^.*:\d\+/
syntax match GitaMatchContent /| \zs.*$/ contains=GitaKeyword
