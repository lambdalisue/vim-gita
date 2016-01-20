let s:save_cpo = &cpo
set cpo&vim

let s:V = hita#vital()
let s:Validate = s:V.import('Vim.Validate')

function! hita#util#validate#true(...) abort
  try
    call call(s:Validate.true, a:000, s:Validate)
  catch /^vital: Vim\.Validate:/
    throw substitute(v:exception, '^vital: Vim\.Validate:', 'vim-hita:', '')
  endtry
endfunction
function! hita#util#validate#false(...) abort
  try
    call call(s:Validate.false, a:000, s:Validate)
  catch /^vital: Vim\.Validate:/
    throw substitute(v:exception, '^vital: Vim\.Validate:', 'vim-hita:', '')
  endtry
endfunction
function! hita#util#validate#exists(...) abort
  try
    call call(s:Validate.exists, a:000, s:Validate)
  catch /^vital: Vim\.Validate:/
    throw substitute(v:exception, '^vital: Vim\.Validate:', 'vim-hita:', '')
  endtry
endfunction
function! hita#util#validate#not_exists(...) abort
  try
    call call(s:Validate.not_exists, a:000, s:Validate)
  catch /^vital: Vim\.Validate:/
    throw substitute(v:exception, '^vital: Vim\.Validate:', 'vim-hita:', '')
  endtry
endfunction
function! hita#util#validate#key_exists(...) abort
  try
    call call(s:Validate.key_exists, a:000, s:Validate)
  catch /^vital: Vim\.Validate:/
    throw substitute(v:exception, '^vital: Vim\.Validate:', 'vim-hita:', '')
  endtry
endfunction
function! hita#util#validate#key_not_exists(...) abort
  try
    call call(s:Validate.key_not_exists, a:000, s:Validate)
  catch /^vital: Vim\.Validate:/
    throw substitute(v:exception, '^vital: Vim\.Validate:', 'vim-hita:', '')
  endtry
endfunction
function! hita#util#validate#empty(...) abort
  try
    call call(s:Validate.empty, a:000, s:Validate)
  catch /^vital: Vim\.Validate:/
    throw substitute(v:exception, '^vital: Vim\.Validate:', 'vim-hita:', '')
  endtry
endfunction
function! hita#util#validate#not_empty(...) abort
  try
    call call(s:Validate.not_empty, a:000, s:Validate)
  catch /^vital: Vim\.Validate:/
    throw substitute(v:exception, '^vital: Vim\.Validate:', 'vim-hita:', '')
  endtry
endfunction
function! hita#util#validate#pattern(...) abort
  try
    call call(s:Validate.pattern, a:000, s:Validate)
  catch /^vital: Vim\.Validate:/
    throw substitute(v:exception, '^vital: Vim\.Validate:', 'vim-hita:', '')
  endtry
endfunction
function! hita#util#validate#not_pattern(...) abort
  try
    call call(s:Validate.not_pattern, a:000, s:Validate)
  catch /^vital: Vim\.Validate:/
    throw substitute(v:exception, '^vital: Vim\.Validate:', 'vim-hita:', '')
  endtry
endfunction

let &cpo = s:save_cpo
unlet! s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
