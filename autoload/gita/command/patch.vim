let s:V = gita#vital()
let s:Anchor = s:V.import('Vim.Buffer.Anchor')
let s:ArgumentParser = s:V.import('ArgumentParser')

function! gita#command#patch#open(...) abort
  let options = extend({
        \ 'method': '',
        \}, get(a:000, 0, {}))
  let method = empty(options.method)
        \ ? g:gita#command#patch#default_method
        \ : options.method
  if method ==# 'one'
    call gita#command#patch#open1(options)
  elseif method ==# 'two'
    call gita#command#patch#open2(options)
  else
    call gita#command#patch#open3(options)
  endif
endfunction

function! gita#command#patch#open1(...) abort
  let options = extend({
        \ 'reverse': 0,
        \ 'filename': '',
        \ 'opener': 'edit',
        \ 'selection': [],
        \}, get(a:000, 0, {}))
  if options.reverse
    let options.cached = 1
  endif
  let options['commit'] = ''
  let options['split'] = 0
  call gita#command#diff#open(options)
endfunction

function! gita#command#patch#open2(...) abort
  let options = extend({
        \ 'reverse': 0,
        \ 'filename': '',
        \ 'opener': 'edit',
        \ 'selection': [],
        \}, get(a:000, 0, {}))
  let filename = empty(options.filename) ? '%' : options.filename
  let filename = gita#variable#get_valid_filename(filename)
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
  if s:Anchor.is_available(options.opener)
    call s:Anchor.focus()
  endif
  call gita#command#show#open(extend(roptions, {
        \ 'window': 'patch2_rhs',
        \ 'opener': options.opener,
        \}))
  call gita#util#diffthis()
  call gita#command#show#open(extend(loptions, {
        \ 'window': 'patch2_lhs',
        \ 'opener': vertical ==# 'vertical'
        \   ? 'leftabove vertical split'
        \   : 'leftabove split',
        \}))
  call gita#util#diffthis()
  call gita#util#select(options.selection)
  diffupdate
  if options.reverse
    keepjumps wincmd p
  endif
endfunction

function! gita#command#patch#open3(...) abort
  let options = extend({
        \ 'filename': '',
        \ 'opener': 'edit',
        \ 'selection': [],
        \}, get(a:000, 0, {}))
  let filename = empty(options.filename) ? '%' : options.filename
  let filename = gita#variable#get_valid_filename(filename)
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
  if s:Anchor.is_available(options.opener)
    call s:Anchor.focus()
  endif
  call gita#command#show#open(extend(roptions, {
        \ 'window': 'patch3_rhs',
        \ 'opener': options.opener,
        \}))
  call gita#util#diffthis()
  let rhs_bufnum = bufnr('%')

  call gita#command#show#open(extend(coptions, {
        \ 'window': 'patch3_chs',
        \ 'opener': vertical ==# 'vertical'
        \   ? 'leftabove vertical split'
        \   : 'leftabove split',
        \}))
  call gita#util#diffthis()
  let chs_bufnum = bufnr('%')

  call gita#command#show#open(extend(loptions, {
        \ 'window': 'patch3_lhs',
        \ 'opener': vertical ==# 'vertical'
        \   ? 'leftabove vertical split'
        \   : 'leftabove split',
        \}))
  call gita#util#diffthis()
  let lhs_bufnum = bufnr('%')

  " define three-way merge special functions
  execute printf(
        \ 'nnoremap <silent><buffer> <Plug>(gita-diffput) :diffput %d<BAR>diffupdate<CR>',
        \ chs_bufnum,
        \)
  if !g:gita#command#patch#disable_default_mappings
    nmap <buffer> dp <Plug>(gita-diffput)
  endif

  execute printf('keepjumps %dwincmd w', bufwinnr(rhs_bufnum))
  execute printf(
        \ 'nnoremap <silent><buffer> <Plug>(gita-diffput) :diffput %d<BAR>diffupdate<CR>',
        \ chs_bufnum,
        \)
  if !g:gita#command#patch#disable_default_mappings
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
  if !g:gita#command#patch#disable_default_mappings
    nmap <buffer> dol <Plug>(gita-diffget-l)
    nmap <buffer> dor <Plug>(gita-diffget-r)
  endif

  call gita#util#select(options.selection)
  diffupdate
endfunction

function! s:get_parser() abort
  if !exists('s:parser') || g:gita#develop
    let s:parser = s:ArgumentParser.new({
          \ 'name': 'Gita patch',
          \ 'description': 'Partially add/reset changes of index',
          \ 'complete_threshold': g:gita#complete_threshold,
          \})
    call s:parser.add_argument(
          \ '--opener', '-o',
          \ 'a way to open a new buffer such as "edit", "split", etc.', {
          \   'type': s:ArgumentParser.types.value,
          \})
    call s:parser.add_argument(
          \ '--reverse',
          \ 'compare difference from HEAD instead of working tree', {
          \   'superordinates': ['one', 'two'],
          \})
    call s:parser.add_argument(
          \ '--one', '-1',
          \ 'open a patchable diff buffer', {
          \   'conflicts': ['two', 'three'],
          \})
    call s:parser.add_argument(
          \ '--two', '-2',
          \ 'open a patchable index and workspace buffers', {
          \   'conflicts': ['one', 'three'],
          \})
    call s:parser.add_argument(
          \ '--three', '-3',
          \ 'open a HEAD, patchable index, and workspace buffers', {
          \   'conflicts': ['one', 'two'],
          \})
    call s:parser.add_argument(
          \ 'filename',
          \ 'a filename going to be patched. if omited, the current buffer is used', {
          \   'complete': function('gita#variable#complete_filename'),
          \})
    function! s:parser.hooks.post_validate(options) abort
      if get(a:options, 'one')
        let a:options.method = 'one'
      elseif get(a:options, 'two')
        let a:options.method = 'two'
      else
        let a:options.method = 'three'
      endif
    endfunction
    call s:parser.hooks.validate()
  endif
  return s:parser
endfunction
function! gita#command#patch#command(...) abort
  let parser  = s:get_parser()
  let options = call(parser.parse, a:000, parser)
  if empty(options)
    return
  endif
  call gita#option#assign_filename(options)
  call gita#option#assign_selection(options)
  call gita#option#assign_opener(options, g:gita#command#patch#default_opener)
  " extend default options
  let options = extend(
        \ deepcopy(g:gita#command#patch#default_options),
        \ options,
        \)
  call gita#command#patch#open(options)
endfunction
function! gita#command#patch#complete(...) abort
  let parser = s:get_parser()
  return call(parser.complete, a:000, parser)
endfunction

call gita#util#define_variables('command#patch', {
      \ 'default_options': {},
      \ 'default_opener': '',
      \ 'default_method': 'three',
      \ 'disable_default_mappings': 0,
      \})

