let s:save_cpo = &cpo
set cpo&vim

let s:V = vital#of('vital')
let s:P = s:V.import('System.Filepath')
let s:S = s:V.import('Vim.ScriptLocal')

let s:root = expand('<sfile>:p:h:h:h:h')
let s:file = s:P.join(s:root, 'gita', 'features', 'blame.vim')

let s:sf = s:S.sfuncs(s:file)
silent! unlet! s:stdout
let s:stdout = gita#features#blame#exec({
      \ '--': [s:file],
      \ 'porcelain': 1,
      \}, {
      \ 'echo': 'fail',
      \}).stdout

let s:INNER_COUNT = 10
let s:OUTER_COUNT = 5

function! s:inner_test(fname) abort
  let c = 1
  let gita = gita#get()
  let stdout = deepcopy(s:stdout)
  let start = reltime()
  while c < s:INNER_COUNT
    call s:sf[a:fname](gita, stdout, 80)
    let c += 1
  endwhile
  echomsg reltimestr(reltime(start))
endfunction

function! s:outer_test(fname) abort
  echomsg ""
  echomsg a:fname
  echomsg "=================================================================="
  let c = 1
  while c < s:OUTER_COUNT
    call s:inner_test(a:fname)
    let c += 1
  endwhile
  echomsg "=================================================================="
endfunction
 
function! gita#develop#benchmark#blame_format_chunks#run() abort
  call s:outer_test('format_chunks_callback')
  call s:outer_test('format_chunks_forloop')
endfunction

let &cpo = s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
