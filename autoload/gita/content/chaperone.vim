let s:V = gita#vital()
let s:Path = s:V.import('System.Filepath')
let s:Git = s:V.import('Git')
let s:GitParser = s:V.import('Git.Parser')

function! s:open1(options) abort
  call gita#throw('Gita chaperon --method=one has not implemented yet')
endfunction

function! s:open2(options) abort
  silent windo diffoff
  let options = extend({
        \ 'filename': '',
        \ 'opener': '',
        \ 'selection': [],
        \}, a:options)
  let git = gita#core#get_or_fail()
  let filename = empty(options.filename) ? gita#meta#expand('%') : options.filename
  let filename = s:Path.unixpath(s:Git.relpath(git, filename))
  let vertical = matchstr(&diffopt, 'vertical')
  let roptions = {
        \ 'silent': 1,
        \ 'theirs': 1,
        \ 'filename': filename,
        \ 'opener': options.opener,
        \ 'window': 'chaperone2_rhs',
        \ 'selection': options.selection,
        \}
  let loptions = {
        \ 'silent': 1,
        \ 'worktree': 1,
        \ 'filename': filename,
        \ 'opener': vertical ==# 'vertical'
        \   ? 'leftabove vertical split'
        \   : 'leftabove split',
        \ 'window': 'chaperone2_lhs',
        \ 'selection': options.selection,
        \}
  call gita#content#show#open(roptions)
  call gita#util#diffthis()

  call gita#content#show#open(loptions)
  call gita#util#buffer#edit_content(
        \ s:GitParser.strip_theirs(getline(1, '$'))
        \)
  setlocal modified
  call gita#util#diffthis()
  diffupdate
endfunction

function! s:open3(options) abort
  silent windo diffoff
  let options = extend({
        \ 'filename': '',
        \ 'opener': 'tabedit',
        \ 'selection': [],
        \}, a:options)
  let git = gita#core#get_or_fail()
  let filename = empty(options.filename) ? gita#meta#expand('%') : options.filename
  let filename = s:Path.unixpath(s:Git.relpath(git, filename))
  let vertical = matchstr(&diffopt, 'vertical')
  let roptions = {
        \ 'silent': 1,
        \ 'theirs': 1,
        \ 'filename': filename,
        \ 'opener': options.opener,
        \ 'window': 'chaperone3_rhs',
        \ 'selection': options.selection,
        \}
  let coptions = {
        \ 'silent': 1,
        \ 'worktree': 1,
        \ 'filename': filename,
        \ 'opener': vertical ==# 'vertical'
        \   ? 'leftabove vertical split'
        \   : 'leftabove split',
        \ 'window': 'chaperone3_chs',
        \ 'selection': options.selection,
        \}
  let loptions = {
        \ 'silent': 1,
        \ 'ours': 1,
        \ 'filename': filename,
        \ 'opener': vertical ==# 'vertical'
        \   ? 'leftabove vertical split'
        \   : 'leftabove split',
        \ 'window': 'chaperone3_lhs',
        \ 'selection': options.selection,
        \}
  call gita#content#show#open(roptions)
  call gita#util#diffthis()
  let rhs_bufnum = bufnr('%')

  call gita#content#show#open(coptions)
  call gita#util#buffer#edit_content(
        \ s:GitParser.strip_conflict(getline(1, '$'))
        \)
  setlocal modified
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

call gita#define_variables('content#chaperone', {
      \ 'default_method': 'three',
      \ 'disable_default_mappings': 0,
      \})

