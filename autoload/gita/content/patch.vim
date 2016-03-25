function! s:open1(options) abort
  let options = extend({
        \ 'reverse': 0,
        \ 'filename': '',
        \ 'opener': '',
        \ 'selection': [],
        \}, a:options)
  let options.opener = empty(options.opener)
        \ ? g:gita#content#patch#default_opener
        \ : options.opener
  if options.reverse
    let options.cached = 1
  endif
  let options['commit'] = ''
  let options['split'] = 0
  call gita#content#diff#open(options)
endfunction

function! s:open2(options) abort
  let options = extend({
        \ 'reverse': 0,
        \ 'filename': '',
        \ 'anchor': 0,
        \ 'opener': '',
        \ 'selection': [],
        \}, a:options)
  let filename = empty(options.filename) ? gita#meta#expand('%') : options.filename
  if options.reverse
    let loptions = {
          \ 'commit': 'HEAD',
          \ 'filename': filename,
          \}
    let roptions = {
          \ 'patch': 1,
          \ 'filename': filename,
          \}
  else
    let loptions = {
          \ 'patch': 1,
          \ 'filename': filename,
          \}
    let roptions = {
          \ 'filename': filename,
          \ 'worktree': 1,
          \}
  endif
  let vertical = matchstr(&diffopt, 'vertical')
  let opener = empty(options.opener)
        \ ? g:gita#content#patch#default_opener
        \ : options.opener
  call gita#content#show#open(extend(roptions, {
        \ 'opener': opener,
        \ 'window': 'patch2_rhs',
        \ 'selection': options.selection,
        \}))
  call gita#util#diffthis()
  call gita#content#show#open(extend(loptions, {
        \ 'opener': vertical ==# 'vertical'
        \   ? 'leftabove vertical split'
        \   : 'leftabove split',
        \ 'window': 'patch2_lhs',
        \ 'selection': options.selection,
        \}))
  call gita#util#diffthis()
  diffupdate
  if options.reverse
    keepjumps wincmd p
  endif
endfunction

function! s:open3(options) abort
  let options = extend({
        \ 'filename': '',
        \ 'anchor': 0,
        \ 'opener': '',
        \ 'selection': [],
        \}, a:options)
  let filename = empty(options.filename) ? gita#meta#expand('%') : options.filename
  let loptions = {
        \ 'commit': 'HEAD',
        \ 'filename': filename,
        \}
  let coptions = {
        \ 'patch': 1,
        \ 'filename': filename,
        \}
  let roptions = {
        \ 'filename': filename,
        \ 'worktree': 1,
        \}
  let vertical = matchstr(&diffopt, 'vertical')
  let opener = empty(options.opener)
        \ ? g:gita#content#patch#default_opener
        \ : options.opener
  call gita#content#show#open(extend(roptions, {
        \ 'opener': opener,
        \ 'window': 'patch3_rhs',
        \ 'selection': options.selection,
        \}))
  call gita#util#diffthis()
  let rhs_bufnum = bufnr('%')

  call gita#content#show#open(extend(coptions, {
        \ 'opener': vertical ==# 'vertical'
        \   ? 'leftabove vertical split'
        \   : 'leftabove split',
        \ 'window': 'patch3_chs',
        \ 'selection': options.selection,
        \}))
  call gita#util#diffthis()
  let chs_bufnum = bufnr('%')

  call gita#content#show#open(extend(loptions, {
        \ 'opener': vertical ==# 'vertical'
        \   ? 'leftabove vertical split'
        \   : 'leftabove split',
        \ 'window': 'patch3_lhs',
        \ 'selection': options.selection,
        \}))
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

call gita#util#define_variables('content#patch', {
      \ 'default_opener': '',
      \ 'default_method': 'three',
      \ 'disable_default_mappings': 0,
      \})
