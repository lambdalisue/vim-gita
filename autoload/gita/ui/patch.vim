function! s:open1(options) abort
  let options = extend({
        \ 'reverse': 0,
        \ 'filename': '',
        \ 'opener': '',
        \ 'selection': [],
        \}, a:options)
  let options.opener = empty(options.opener)
        \ ? g:gita#ui#patch#default_opener
        \ : options.opener
  if options.reverse
    let options.cached = 1
  endif
  let options['commit'] = ''
  let options['split'] = 0
  call gita#ui#diff#open(options)
endfunction

function! s:open2(options) abort
  let options = extend({
        \ 'reverse': 0,
        \ 'filename': '',
        \ 'anchor': 0,
        \ 'opener': '',
        \ 'selection': [],
        \}, a:options)
  let git = gita#core#get_or_fail()
  let filename = empty(options.filename) ? '%' : options.filename
  let filename = gita#variable#get_valid_filename(git, filename)
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
        \ ? g:gita#ui#patch#default_opener
        \ : options.opener
  call gita#ui#show#open(extend(roptions, {
        \ 'anchor': options.anchor,
        \ 'opener': opener,
        \ 'window': 'patch2_rhs',
        \}))
  call gita#util#diffthis()
  call gita#ui#show#open(extend(loptions, {
        \ 'anchor': 0,
        \ 'opener': vertical ==# 'vertical'
        \   ? 'leftabove vertical split'
        \   : 'leftabove split',
        \ 'window': 'patch2_lhs',
        \}))
  call gita#util#diffthis()
  call gita#util#select(options.selection)
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
  let git = gita#core#get_or_fail()
  let filename = empty(options.filename) ? '%' : options.filename
  let filename = gita#variable#get_valid_filename(git, filename)
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
        \ ? g:gita#ui#patch#default_opener
        \ : options.opener
  call gita#ui#show#open(extend(roptions, {
        \ 'anchor': options.anchor,
        \ 'opener': opener,
        \ 'window': 'patch3_rhs',
        \}))
  call gita#util#diffthis()
  let rhs_bufnum = bufnr('%')

  call gita#ui#show#open(extend(coptions, {
        \ 'anchor': 0,
        \ 'opener': vertical ==# 'vertical'
        \   ? 'leftabove vertical split'
        \   : 'leftabove split',
        \ 'window': 'patch3_chs',
        \}))
  call gita#util#diffthis()
  let chs_bufnum = bufnr('%')

  call gita#ui#show#open(extend(loptions, {
        \ 'anchor': 0,
        \ 'opener': vertical ==# 'vertical'
        \   ? 'leftabove vertical split'
        \   : 'leftabove split',
        \ 'window': 'patch3_lhs',
        \}))
  call gita#util#diffthis()
  let lhs_bufnum = bufnr('%')

  " define three-way merge special functions
  execute printf(
        \ 'nnoremap <silent><buffer> <Plug>(gita-diffput) :diffput %d<BAR>diffupdate<CR>',
        \ chs_bufnum,
        \)
  if !g:gita#ui#patch#disable_default_mappings
    nmap <buffer> dp <Plug>(gita-diffput)
  endif

  execute printf('keepjumps %dwincmd w', bufwinnr(rhs_bufnum))
  execute printf(
        \ 'nnoremap <silent><buffer> <Plug>(gita-diffput) :diffput %d<BAR>diffupdate<CR>',
        \ chs_bufnum,
        \)
  if !g:gita#ui#patch#disable_default_mappings
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
  if !g:gita#ui#patch#disable_default_mappings
    nmap <buffer> dol <Plug>(gita-diffget-l)
    nmap <buffer> dor <Plug>(gita-diffget-r)
  endif

  call gita#util#select(options.selection)
  diffupdate
endfunction

function! gita#ui#patch#open(...) abort
  let options = extend({
        \ 'method': '',
        \}, get(a:000, 0, {}))
  let method = empty(options.method)
        \ ? g:gita#ui#patch#default_method
        \ : options.method
  if method ==# 'one'
    call s:open1(options)
  elseif method ==# 'two'
    call s:open2(options)
  else
    call s:open3(options)
  endif
endfunction

call gita#util#define_variables('ui#patch', {
      \ 'default_opener': '',
      \ 'default_method': 'three',
      \ 'disable_default_mappings': 0,
      \})
