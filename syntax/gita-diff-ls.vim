if exists('b:current_syntax')
  finish
endif
let b:current_syntax = 'gita-diff-ls'

highlight default link GitaComment Comment
highlight default link GitaAdded   Special
highlight default link GitaDeleted Constant
highlight default link GitaDiffZero Comment

syntax clear
syntax match GitaComment    /\%^.*$/
syntax match GitaDiffLs        /^.\{-} +\d\+\s\+-\d\+\s\++*-*$/
      \ contains=GitaDiffLsSuffix
syntax match GitaDiffLsSuffix  /+\d\+\s\+-\d\+\s\++*-*$/
      \ contains=GitaAdded,GitaDeleted,GitaDiffZero
syntax match GitaAdded   /+[0-9+]*/ contained
syntax match GitaDeleted /-[0-9-]*/ contained
syntax match GitaDiffZero /[+-]0/ contained
