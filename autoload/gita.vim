let s:V = vital#of('gita')
let s:Console = s:V.import('Vim.Console')

function! gita#vital() abort
  return s:V
endfunction

function! gita#throw(msg) abort
  throw 'gita: ' . a:msg
endfunction

function! gita#trigger_modified() abort
  call gita#util#doautocmd('User', 'GitaStatusModifiedPre')
  call gita#util#doautocmd('User', 'GitaStatusModifiedPost')
endfunction

function! gita#define_variables(prefix, defaults) abort
  " NOTE: Funcref is not supported
  let prefix = empty(a:prefix) ? 'g:gita' : 'g:gita#' . a:prefix
  for [key, value] in items(a:defaults)
    let name = prefix . '#' . key
    if !exists(name)
      execute 'let ' . name . ' = ' . string(value)
    endif
    unlet value
  endfor
endfunction

call gita#define_variables('', {
      \ 'test': 0,
      \ 'develop': 0,
      \ 'complete_threshold': 100,
      \ 'suppress_warning': 0,
      \})

let s:Console.batch = g:gita#test

if !g:gita#suppress_warning && !exists('s:has_announced')
  let s:has_announced = 1
  echohl WarningMsg
  redraw
  echomsg '****************************************************************************************'
  echomsg 'The development of lambdalisue/vim-gita moved into lambdalisue/gina.vim.'
  echomsg '----------------------------------------------------------------------------------------'
  echomsg 'Check https://github.com/lambdalisue/gina.vim which is a new implementation of vim-gita'
  echomsg 'To suppress this warning, add "let g:gita#suppress_warning = 1" to user .vimrc'
  echomsg '****************************************************************************************'
  echohl None
endif
