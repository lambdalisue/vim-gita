let s:V = hita#vital()
let s:Validate = s:V.import('Vim.Validate')

function! hita#util#validate#true(...) abort
  call call(s:Validate.true, a:000, s:Validate)
endfunction
function! hita#util#validate#false(...) abort
  call call(s:Validate.false, a:000, s:Validate)
endfunction
function! hita#util#validate#exists(...) abort
  call call(s:Validate.exists, a:000, s:Validate)
endfunction
function! hita#util#validate#not_exists(...) abort
  call call(s:Validate.not_exists, a:000, s:Validate)
endfunction
function! hita#util#validate#key_exists(...) abort
  call call(s:Validate.key_exists, a:000, s:Validate)
endfunction
function! hita#util#validate#key_not_exists(...) abort
  call call(s:Validate.key_not_exists, a:000, s:Validate)
endfunction
function! hita#util#validate#empty(...) abort
  call call(s:Validate.empty, a:000, s:Validate)
endfunction
function! hita#util#validate#not_empty(...) abort
  call call(s:Validate.not_empty, a:000, s:Validate)
endfunction
function! hita#util#validate#pattern(...) abort
  call call(s:Validate.pattern, a:000, s:Validate)
endfunction
function! hita#util#validate#not_pattern(...) abort
  call call(s:Validate.not_pattern, a:000, s:Validate)
endfunction

function! hita#util#validate#throw(...) abort
  call call(s:Validate.throw, a:000, s:Validate)
endfunction

call s:Validate.set_config({
      \ 'prefix': 'vim-hita: ',
      \})
