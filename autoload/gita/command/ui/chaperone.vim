function! s:open1(options) abort
  call gita#throw('Gita chaperon --method=one has not implemented yet')
endfunction

function! s:open2(options) abort
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
        \ 'ours': 1,
        \ 'filename': filename,
        \}
  let roptions = {
        \ 'theirs': 1,
        \ 'filename': filename,
        \}
  let vertical = matchstr(&diffopt, 'vertical')
  let opener = empty(options.opener)
        \ ? g:gita#command#ui#chaperone#default_opener
        \ : options.opener
  call gita#command#ui#show#open(extend(roptions, {
        \ 'anchor': options.anchor,
        \ 'opener': opener,
        \ 'window': 'chaperone2_rhs',
        \}))
  call gita#util#diffthis()

  let result =gita#command#show#call(extend(loptions, {
        \ 'quiet': 1,
        \}))
  call gita#command#ui#show#open({
        \ 'worktree': 1,
        \ 'filename': filename,
        \ 'anchor': 0,
        \ 'opener': vertical ==# 'vertical'
        \   ? 'leftabove vertical split'
        \   : 'leftabove split',
        \ 'window': 'chaperone2_lhs',
        \})
  call gita#util#buffer#edit_content(result.content)
  setlocal modified
  call gita#util#diffthis()
  call gita#util#select(options.selection)
  diffupdate
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
        \ 'ours': 1,
        \ 'filename': filename,
        \}
  let coptions = {
        \ 'ancestors': 1,
        \ 'filename': filename,
        \}
  let roptions = {
        \ 'theirs': 1,
        \ 'filename': filename,
        \}
  let vertical = matchstr(&diffopt, 'vertical')
  let opener = empty(options.opener)
        \ ? g:gita#command#ui#chaperone#default_opener
        \ : options.opener
  call gita#command#ui#show#open(extend(roptions, {
        \ 'anchor': options.anchor,
        \ 'opener': opener,
        \ 'window': 'chaperone3_rhs',
        \}))
  call gita#util#diffthis()
  let rhs_bufnum = bufnr('%')

  let result =gita#command#show#call(extend(coptions, {
        \ 'quiet': 1,
        \}))
  call gita#command#ui#show#open({
        \ 'worktree': 1,
        \ 'filename': filename,
        \ 'anchor': 0,
        \ 'opener': vertical ==# 'vertical'
        \   ? 'leftabove vertical split'
        \   : 'leftabove split',
        \ 'window': 'chaperone3_chs',
        \})
  call gita#util#buffer#edit_content(result.content)
  setlocal modified
  call gita#util#diffthis()
  let chs_bufnum = bufnr('%')

  call gita#command#ui#show#open(extend(loptions, {
        \ 'anchor': 0,
        \ 'opener': vertical ==# 'vertical'
        \   ? 'leftabove vertical split'
        \   : 'leftabove split',
        \ 'window': 'chaperone3_lhs',
        \}))
  call gita#util#diffthis()
  let lhs_bufnum = bufnr('%')

  " define three-way merge special functions
  execute printf(
        \ 'nnoremap <silent><buffer> <Plug>(gita-diffput) :diffput %d<BAR>diffupdate<CR>',
        \ chs_bufnum,
        \)
  if !g:gita#command#ui#chaperone#disable_default_mappings
    nmap <buffer> dp <Plug>(gita-diffput)
  endif

  execute printf('keepjumps %dwincmd w', bufwinnr(rhs_bufnum))
  execute printf(
        \ 'nnoremap <silent><buffer> <Plug>(gita-diffput) :diffput %d<BAR>diffupdate<CR>',
        \ chs_bufnum,
        \)
  if !g:gita#command#ui#chaperone#disable_default_mappings
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
  if !g:gita#command#ui#chaperone#disable_default_mappings
    nmap <buffer> dol <Plug>(gita-diffget-l)
    nmap <buffer> dor <Plug>(gita-diffget-r)
  endif

  call gita#util#select(options.selection)
  diffupdate
endfunction

function! gita#command#ui#chaperone#open(...) abort
  let options = extend({
        \ 'method': '',
        \}, get(a:000, 0, {}))
  let method = empty(options.method)
        \ ? g:gita#command#ui#chaperone#default_method
        \ : options.method
  if method ==# 'one'
    call s:open1(options)
  elseif method ==# 'two'
    call s:open2(options)
  else
    call s:open3(options)
  endif
endfunction

call gita#util#define_variables('command#ui#chaperone', {
      \ 'default_opener': '',
      \ 'default_method': 'three',
      \ 'disable_default_mappings': 0,
      \})
