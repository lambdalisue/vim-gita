let s:V = vital#of('gita')
let s:Prompt = s:V.import('Vim.Prompt')

function! gita#vital() abort
  return s:V
endfunction

function! gita#throw(msg) abort
  throw 'vim-gita: ' . a:msg
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
      \ 'develop': 1,
      \ 'complete_threshold': 100,
      \})

call s:Prompt.set_config({
      \ 'batch': g:gita#test,
      \})
