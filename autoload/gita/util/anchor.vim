let s:V = gita#vital()
let s:Anchor = s:V.import('Vim.Buffer.Anchor')

function! gita#util#anchor#is_available(opener) abort
  return s:Anchor.is_available(a:opener)
endfunction

function! gita#util#anchor#focus() abort
  return s:Anchor.focus()
endfunction

function! gita#util#anchor#attach() abort
  return s:Anchor.attach()
endfunction
