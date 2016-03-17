if exists('b:current_syntax')
  finish
endif
let b:current_syntax = 'gita-blame-navi'

sign define GitaPseudoSeparatorSign texthl=SignColumn linehl=GitaPseudoSeparator
sign define GitaPseudoEmptySign

highlight default link GitaPseudoSeparator GitaPseudoSeparatorDefault
highlight default link GitaHorizontal Comment
highlight default link GitaSummary    Title
highlight default link GitaMetaInfo   Comment
highlight default link GitaAuthor     Identifier
highlight default link GitaNotCommittedYet Constant
highlight default link GitaTimeDelta  Comment
highlight default link GitaRevision   String
highlight default link GitaLineNr     LineNr

syntax clear
syntax match GitaSummary   /.*/ contains=GitaLineNr,GitaMetaInfo
syntax match GitaLineNr    /^\s*[0-9]\+/
syntax match GitaMetaInfo  /\%(\w\+ authored\|Not committed yet\) .*$/
      \ contains=GitaAuthor,GitaNotCommittedYet,GitaTimeDelta,GitaRevision
syntax match GitaAuthor    /\w\+\ze authored/ contained
syntax match GitaNotCommittedYet /Not committed yet/ contained
syntax match GitaTimeDelta /authored \zs.*\ze\s\+[0-9a-fA-F]\{7}$/ contained
syntax match GitaRevision  /[0-9a-fA-F]\{7}$/ contained
