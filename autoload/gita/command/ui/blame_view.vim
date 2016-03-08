let s:BLAME_NAVI_WIDTH = 50

function! s:define_actions() abort
endfunction

function! s:on_BufReadCmd(options) abort
  let options = gita#option#init('^blame-', a:options, {
        \ 'selection': [],
        \})
  let result = gita#command#blame#call(options)
  let result.blamemeta = gita#command#blame#format(
        \ result.blameobj,
        \ s:BLAME_NAVI_WIDTH
        \)
  call s:define_actions()
  call gita#meta#set('content_type', 'blame-view')
  call gita#meta#set('blameobj', result.blameobj)
  call gita#meta#set('blamemeta', blamemeta)
  call gita#meta#set('commit', options.commit)
  call gita#meta#set('filename', options.filename)
endfunction
