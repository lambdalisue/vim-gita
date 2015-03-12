"******************************************************************************
" vim-gita utility
"
" Author:   Alisue <lambdalisue@hashnote.net>
" URL:      http://hashnote.net/
" License:  MIT license
" (C) 2015, Alisue, hashnote.net
"******************************************************************************
let s:save_cpo = &cpo
set cpo&vim

function! gita#utils#trancate(str, length) abort " {{{
  if len(a:str) > a:length
    return a:str[0:a:length-5] . ' ...'
  endif
  return a:str
endfunction " }}}
function! gita#utils#get_bufwidth() abort " {{{
  if &l:number
    let gwidth = &l:numberwidth
  else
    let gwidth = 0
  endif
  let fwidth = &l:foldcolumn
  let wwidth = winwidth(0)
  return wwidth - gwidth - fwidth
endfunction " }}}
function! gita#utils#call_on_buffer(expr, funcref, ...) abort " {{{
  let cbufnr = bufnr('%')
  let save_lazyredraw = &lazyredraw
  let &lazyredraw = 1
  if type(a:expr) == 0
    let tbufnr = a:expr
  else
    let tbufnr = bufnr(a:expr)
  endif
  if tbufnr == -1
    " no buffer is opened yet
    return 0
  endif
  let cwinnr = winnr()
  let twinnr = bufwinnr(tbufnr)
  if twinnr == -1
    " no window is opened
    execute tbufnr . 'buffer'
    call call(a:funcref, a:000)
    execute cbufnr . 'buffer'
  else
    execute twinnr . 'wincmd w'
    call call(a:funcref, a:000)
    execute cwinnr . 'wincmd w'
  endif
  let &lazyredraw = save_lazyredraw
  return 1
endfunction " }}}
function! gita#utils#input_yesno(message, ...) "{{{
  " forked from Shougo/unite.vim
  " AUTHOR: Shougo Matsushita <Shougo.Matsu@gmail.com>
  " License: MIT license  {{{
  "     Permission is hereby granted, free of charge, to any person obtaining
  "     a copy of this software and associated documentation files (the
  "     "Software"), to deal in the Software without restriction, including
  "     without limitation the rights to use, copy, modify, merge, publish,
  "     distribute, sublicense, and/or sell copies of the Software, and to
  "     permit persons to whom the Software is furnished to do so, subject to
  "     the following conditions:
  "
  "     The above copyright notice and this permission notice shall be included
  "     in all copies or substantial portions of the Software.
  "
  "     THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
  "     OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
  "     MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
  "     IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
  "     CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
  "     TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
  "     SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
  " }}}
  let default = get(a:000, 0, '')
  let yesno = input(a:message . ' [yes/no]: ', default)
  while yesno !~? '^\%(y\%[es]\|n\%[o]\)$'
    redraw
    if yesno == ''
      echo 'Canceled.'
      break
    endif
    " Retry.
    call unite#print_error('Invalid input.')
    let yesno = input(a:message . ' [yes/no]: ')
  endwhile
  redraw
  return yesno =~? 'y\%[es]'
endfunction " }}}
function! gita#utils#browse(url) abort " {{{
  try
    call openbrowser#open(a:url)
  catch /E117.*/
    " exists("*openbrowser#open") could not be used while this might be the
    " first time to call an autoload function.
    " Thus catch "E117: Unknown function" exception to check if there is a
    " newly implemented function or not.
    redraw
    echohl WarningMsg
    echo  'vim-gita require "tyru/open-browser.vim" plugin to oepn browsers. '
    echon 'It seems you have not installed that plugin yet. So ignore it.'
    echohl None
  endtry
endfunction " }}}
function! gita#utils#getbufvar(expr, name, ...) abort " {{{
  " Ref: https://github.com/vim-jp/issues/issues/245#issuecomment-13858947
  let default = get(a:000, 0, '')
  if v:version > 703 || (v:version == 703 && has('patch831'))
    return getbufvar(a:expr, a:name, default)
  else
    let value = getbufvar(a:expr, a:name)
    if type(value) == 1 && empty(value)
      return default
    endif
    return default
  endif
endfunction " }}}
function! gita#utils#get_usable_buffer_name(name) abort " {{{
  if bufnr(a:name) == -1
    return a:name
  endif
  let index = 1
  let filename = fnamemodify(a:name, ':t')
  let basename = fnamemodify(a:name, ':r')
  let extension = fnamemodify(a:name, ':e')
  while bufnr(filename) > -1
    let index += 1
    let filename = printf("%s-%d.%s", basename, index, extension)
  endwhile
  return filename
endfunction " }}}

let &cpo = s:save_cpo
unlet s:save_cpo
"vim: sts=2 sw=2 smarttab et ai textwidth=0 fdm=marker

