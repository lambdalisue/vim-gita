let s:save_cpoptions = &cpoptions
set cpoptions&vim

let s:INNER_COUNT = 10
let s:OUTER_COUNT = 5

function! s:inner_test(name) abort
  let c = 1
  let start = reltime()
  while c < s:INNER_COUNT
    call gita#statusline#preset(a:name)
    let c += 1
  endwhile
  echomsg reltimestr(reltime(start))
endfunction

function! s:outer_test(name) abort
  echomsg ""
  echomsg printf('gita#statusline#preset("%s")', a:name)
  echomsg "=================================================================="
  let c = 1
  while c < s:OUTER_COUNT
    call s:inner_test(a:name)
    let c += 1
  endwhile
  echomsg "=================================================================="
endfunction
 
function! gita#develop#benchmark#statusline#run() abort
  call s:outer_test('branch')
  call s:outer_test('status')
  call s:outer_test('traffic')
endfunction

let &cpoptions = s:save_cpoptions
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
