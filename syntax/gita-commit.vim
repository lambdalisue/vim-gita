if exists('b:current_syntax')
  finish
endif
let b:current_syntax = 'gita-commit'

highlight default link GitaComment    Comment
highlight default link GitaConflicted Error
highlight default link GitaUnstaged   Constant
highlight default link GitaStaged     Special
highlight default link GitaUntracked  GitaUnstaged
highlight default link GitaIgnored    Identifier
highlight default link GitaBranch     Title
highlight default link GitaHighlight  Keyword
highlight default link GitaImportant  Constant

syntax clear
syntax match GitaStaged     /^# [ MADRC][ MD]/hs=s+2,he=e-1 contains=ALL
syntax match GitaUnstaged   /^# [ MADRC][ MD]/hs=s+3 contains=ALL
syntax match GitaStaged     /^# [ MADRC]\s.*$/hs=s+5 contains=ALL
syntax match GitaUnstaged   /^# .[MDAU?].*$/hs=s+5 contains=ALL
syntax match GitaIgnored    /^# !!\s.*$/hs=s+2
syntax match GitaUntracked  /^# ??\s.*$/hs=s+2
syntax match GitaConflicted /^# \%(DD\|AU\|UD\|UA\|DU\|AA\|UU\)\s.*$/hs=s+2
syntax match GitaComment    /^# .*$/ contains=ALL
syntax match GitaBranch     /status of [^ ]\+/hs=s+10 contained
syntax match GitaBranch     /status of [^ ]\+ <> [^ ]\+/hs=s+10 contained
syntax match GitaHighlight  /\d\+ commit(s) ahead/ contained
syntax match GitaHighlight  /\d\+ commit(s) behind/ contained
syntax match GitaImportant  /REBASE-[mi] \d\/\d/
syntax match GitaImportant  /REBASE \d\/\d/
syntax match GitaImportant  /AM \d\/\d/
syntax match GitaImportant  /AM\/REBASE \d\/\d/
syntax match GitaImportant  /\%(MERGING\|CHERRY-PICKING\|REVERTING\|BISECTING\)/
