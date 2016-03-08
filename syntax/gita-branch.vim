if exists('b:current_syntax')
  finish
endif
let b:current_syntax = 'gita-branch'

highlight default link GitaComment    Comment
highlight default link GitaSelected   Special
highlight default link GitaRemote     Constant

syntax clear
syntax match GitaComment    /\%^.*$/
syntax match GitaSelected   /^\* [^ ]\+/hs=s+2
syntax match GitaRemote     /^..remotes\/[^ ]\+/hs=s+2
