function! s:open1(options) abort
  let options = extend({
        \ 'reverse': 0,
        \ 'filename': '',
        \ 'opener': '',
        \ 'selection': [],
        \}, a:options)
  if options.reverse
    let options.cached = 1
  endif
  let options.commit = ''
  let options.split = 0
  let options.patch = 1
  call gita#content#diff#open(options)
endfunction

function! s:open2(options) abort
  silent windo diffoff
  let options = extend({
        \ 'reverse': 0,
        \ 'filename': '',
        \ 'opener': '',
        \ 'selection': [],
        \}, a:options)
  let filename = empty(options.filename) ? gita#meta#expand('%') : options.filename
  let vertical = matchstr(&diffopt, 'vertical')
  let roptions = {
        \ 'silent': 1,
        \ 'patch': options.reverse,
        \ 'worktree': !options.reverse,
        \ 'filename': filename,
        \ 'opener': options.opener,
        \ 'window': 'patch2_rhs',
        \ 'selection': options.selection,
        \}
  let loptions = {
        \ 'silent': 1,
        \ 'commit': options.reverse ? 'HEAD' : '',
        \ 'patch':  !options.reverse,
        \ 'filename': filename,
        \ 'opener': vertical ==# 'vertical'
        \   ? 'leftabove vertical split'
        \   : 'leftabove split',
        \ 'window': 'patch2_lhs',
        \ 'selection': options.selection,
        \}
  call gita#content#show#open(roptions)
  call gita#util#diffthis()

  call gita#content#show#open(loptions)
  call gita#util#diffthis()
  diffupdate
  if options.reverse
    keepjumps wincmd p
  endif
endfunction

function! s:open3(options) abort
  silent windo diffoff
  let options = extend({
        \ 'filename': '',
        \ 'opener': 'tabedit',
        \ 'selection': [],
        \}, a:options)
  let filename = empty(options.filename) ? gita#meta#expand('%') : options.filename
  let vertical = matchstr(&diffopt, 'vertical')
  let roptions = {
        \ 'silent': 1,
        \ 'filename': filename,
        \ 'worktree': 1,
        \ 'opener': options.opener,
        \ 'window': 'patch3_rhs',
        \ 'selection': options.selection,
        \}
  let coptions = {
        \ 'silent': 1,
        \ 'patch': 1,
        \ 'filename': filename,
        \ 'opener': vertical ==# 'vertical'
        \   ? 'leftabove vertical split'
        \   : 'leftabove split',
        \ 'window': 'patch3_chs',
        \ 'selection': options.selection,
        \}
  let loptions = {
        \ 'silent': 1,
        \ 'commit': 'HEAD',
        \ 'filename': filename,
        \ 'opener': vertical ==# 'vertical'
        \   ? 'leftabove vertical split'
        \   : 'leftabove split',
        \ 'window': 'patch3_lhs',
        \ 'selection': options.selection,
        \}
  call gita#content#show#open(roptions)
  call gita#util#diffthis()
  let rhs_bufnum = bufnr('%')

  call gita#content#show#open(coptions)
  call gita#util#diffthis()
  let chs_bufnum = bufnr('%')

  call gita#content#show#open(loptions)
  call gita#util#diffthis()
  let lhs_bufnum = bufnr('%')

  " define three-way merge special functions
  execute printf(
        \ 'nnoremap <silent><buffer> <Plug>(gita-diffput) :diffput %d<BAR>diffupdate<CR>',
        \ chs_bufnum,
        \)
  if !g:gita#content#patch#disable_default_mappings
    nmap <buffer> dp <Plug>(gita-diffput)
  endif

  execute printf('keepjumps %dwincmd w', bufwinnr(rhs_bufnum))
  execute printf(
        \ 'nnoremap <silent><buffer> <Plug>(gita-diffput) :diffput %d<BAR>diffupdate<CR>',
        \ chs_bufnum,
        \)
  if !g:gita#content#patch#disable_default_mappings
    nmap <buffer> dp <Plug>(gita-diffput)
  endif

  execute printf('keepjumps %dwincmd w', bufwinnr(chs_bufnum))
  execute printf(
        \ 'nnoremap <silent><buffer> <Plug>(gita-diffget-l) :diffget %d<BAR>diffupdate<CR>',
        \ lhs_bufnum,
        \)
  execute printf(
        \ 'nnoremap <silent><buffer> <Plug>(gita-diffget-r) :diffget %d<BAR>diffupdate<CR>',
        \ rhs_bufnum,
        \)
  if !g:gita#content#patch#disable_default_mappings
    nmap <buffer> dol <Plug>(gita-diffget-l)
    nmap <buffer> dor <Plug>(gita-diffget-r)
  endif

  diffupdate
endfunction

function! gita#content#patch#open(options) abort
  let options = extend({
        \ 'method': '',
        \}, a:options)
  let method = empty(options.method)
        \ ? g:gita#content#patch#default_method
        \ : options.method
  if method ==# 'one'
    call s:open1(options)
  elseif method ==# 'two'
    call s:open2(options)
  else
    call s:open3(options)
  endif
endfunction

call gita#define_variables('content#patch', {
      \ 'default_method': 'three',
      \ 'disable_default_mappings': 0,
      \})
