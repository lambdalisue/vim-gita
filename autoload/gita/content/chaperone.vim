let s:V = gita#vital()
let s:Path = s:V.import('System.Filepath')
let s:Git = s:V.import('Git')

function! s:open1(options) abort
  call gita#throw('Gita chaperon --method=one has not implemented yet')
endfunction

function! s:open2(options) abort
  let options = extend({
        \ 'filename': '',
        \ 'opener': '',
        \ 'selection': [],
        \}, a:options)
  let git = gita#core#get_or_fail()
  let filename = empty(options.filename) ? gita#meta#expand('%') : options.filename
  let filename = s:Path.unixpath(s:Git.get_relative_path(git, filename))
  let roptions = {
        \ 'theirs': 1,
        \ 'filename': filename,
        \}
  let vertical = matchstr(&diffopt, 'vertical')
  let opener = empty(options.opener)
        \ ? g:gita#content#chaperone#default_opener
        \ : options.opener
  call gita#content#show#open(extend(roptions, {
        \ 'opener': opener,
        \ 'window': 'chaperone2_rhs',
        \ 'selection': options.selection,
        \}))
  call gita#util#diffthis()

  let content = gita#command#execute([
        \ 'show', ':2:' . filename,
        \], { 'quiet': 1 },
        \)
  call gita#content#show#open({
        \ 'worktree': 1,
        \ 'filename': filename,
        \ 'opener': vertical ==# 'vertical'
        \   ? 'leftabove vertical split'
        \   : 'leftabove split',
        \ 'window': 'chaperone2_lhs',
        \ 'selection': options.selection,
        \})
  call gita#util#buffer#edit_content(content)
  setlocal modified
  call gita#util#diffthis()
  diffupdate
endfunction

function! s:open3(options) abort
  let options = extend({
        \ 'filename': '',
        \ 'opener': '',
        \ 'selection': [],
        \}, a:options)
  let git = gita#core#get_or_fail()
  let filename = empty(options.filename) ? gita#meta#expand('%') : options.filename
  let filename = s:Path.unixpath(s:Git.get_relative_path(git, filename))
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
        \ ? g:gita#content#chaperone#default_opener
        \ : options.opener
  call gita#content#show#open(extend(roptions, {
        \ 'opener': opener,
        \ 'window': 'chaperone3_rhs',
        \ 'selection': options.selection,
        \}))
  call gita#util#diffthis()
  let rhs_bufnum = bufnr('%')

  let content = gita#command#execute([
        \ 'show', ':1:' . filename,
        \], { 'quiet': 1 },
        \)
  call gita#content#show#open({
        \ 'worktree': 1,
        \ 'filename': filename,
        \ 'opener': vertical ==# 'vertical'
        \   ? 'leftabove vertical split'
        \   : 'leftabove split',
        \ 'window': 'chaperone3_chs',
        \ 'selection': options.selection,
        \})
  call gita#util#buffer#edit_content(content)
  setlocal modified
  call gita#util#diffthis()
  let chs_bufnum = bufnr('%')

  call gita#content#show#open(extend(loptions, {
        \ 'opener': vertical ==# 'vertical'
        \   ? 'leftabove vertical split'
        \   : 'leftabove split',
        \ 'window': 'chaperone3_lhs',
        \ 'selection': options.selection,
        \}))
  call gita#util#diffthis()
  let lhs_bufnum = bufnr('%')

  " define three-way merge special functions
  execute printf(
        \ 'nnoremap <silent><buffer> <Plug>(gita-diffput) :diffput %d<BAR>diffupdate<CR>',
        \ chs_bufnum,
        \)
  if !g:gita#content#chaperone#disable_default_mappings
    nmap <buffer> dp <Plug>(gita-diffput)
  endif

  execute printf('keepjumps %dwincmd w', bufwinnr(rhs_bufnum))
  execute printf(
        \ 'nnoremap <silent><buffer> <Plug>(gita-diffput) :diffput %d<BAR>diffupdate<CR>',
        \ chs_bufnum,
        \)
  if !g:gita#content#chaperone#disable_default_mappings
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
  if !g:gita#content#chaperone#disable_default_mappings
    nmap <buffer> dol <Plug>(gita-diffget-l)
    nmap <buffer> dor <Plug>(gita-diffget-r)
  endif
  diffupdate
endfunction

function! gita#content#chaperone#open(...) abort
  let options = extend({
        \ 'method': '',
        \}, get(a:000, 0, {}))
  let method = empty(options.method)
        \ ? g:gita#content#chaperone#default_method
        \ : options.method
  if method ==# 'one'
    call s:open1(options)
  elseif method ==# 'two'
    call s:open2(options)
  else
    call s:open3(options)
  endif
endfunction

call gita#util#define_variables('content#chaperone', {
      \ 'default_opener': 'tabedit',
      \ 'default_method': 'three',
      \ 'disable_default_mappings': 0,
      \})

