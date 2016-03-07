let s:V = gita#vital()
let s:Dict = s:V.import('Data.Dict')
let s:Anchor = s:V.import('Vim.Buffer.Anchor')
let s:Git = s:V.import('Git')
let s:GitTerm = s:V.import('Git.Term')
let s:WORKTREE = '@@'  " @@ is not valid commit thus

function! s:configure_options(options) abort
  if a:options.patch
    " 'patch' mode requires:
    " - Existence of INDEX, namely no commit or --cached
    let commit = get(a:options, 'commit', '')
    if empty(commit)
      " INDEX vs HEAD
      let a:options.cached = 0
      let a:options.reverse = 0
    elseif commit =~# '^.\{-}\.\.\.?.*$'
      " RANGE is not allowed
      call gita#throw(printf(
            \ 'A commit range "%s" is not allowed for PATCH mode.',
            \ commit,
            \))
    else
      " COMMIT vs INDEX
      let a:options.cached = 1
      let a:options.reverse = 1
    endif
  endif
endfunction

function! s:open1(options) abort
  let options = extend({
        \ 'anchor': 0,
        \ 'opener': '',
        \ 'window': '',
        \ 'selection': [],
        \}, a:options)
  let bufname = gita#command#ui#diff#bufname(options)
  let opener = empty(options.opener)
        \ ? g:gita#command#ui#diff#default_opener
        \ : options.opener
  if options.anchor && s:Anchor.is_available(opener)
    call s:Anchor.focus()
  endif
  call gita#util#cascade#set('diff', options)
  call gita#util#buffer#open(bufname, {
        \ 'opener': opener,
        \ 'window': options.window,
        \})
  call gita#util#select(options.selection)
endfunction

function! s:open2(options) abort
  let options = extend({
        \ 'anchor': 0,
        \ 'patch': 0,
        \ 'cached': 0,
        \ 'reverse': 0,
        \ 'commit': '',
        \ 'filename': '',
        \ 'opener': '',
        \ 'selection': [],
        \}, a:options)
  call s:configure_options(options)
  let commit = gita#variable#get_valid_range(options.commit, {
        \ '_allow_empty': 1,
        \})
  let filename = empty(options.filename) ? '%' : options.filename
  let filename = gita#variable#get_valid_filename(filename)
  if empty(commit)
    " git diff          : INDEX vs TREE
    " git diff --cached :  HEAD vs INDEX
    let lhs = options.cached ? 'HEAD' : ''
    let rhs = options.cached ? '' : s:WORKTREE
  elseif commit =~# '^.\{-}\.\.\..*$'
    " git diff <lhs>...<rhs> : <lhs>...<rhs> vs <rhs>
    let [lhs, rhs] = s:GitTerm.split_range(commit)
    let lhs = commit
    let rhs = empty(rhs) ? 'HEAD' : rhs
  elseif commit =~# '^.\{-}\.\.\..*$'
    " git diff <lhs>..<rhs> : <lhs> vs <rhs>
    let [lhs, rhs] = s:GitTerm.split_range(commit)
    let lhs = empty(lhs) ? 'HEAD' : lhs
    let rhs = empty(rhs) ? 'HEAD' : rhs
  else
    " git diff <ref>          : <ref> vs TREE
    " git diff --cached <ref> : <ref> vs INDEX
    let lhs = commit
    let rhs = options.cached ? '' : s:WORKTREE
  endif
  let loptions = {
        \ 'patch': !options.reverse && options.patch,
        \ 'commit': lhs,
        \ 'filename': filename,
        \ 'worktree': lhs ==# s:WORKTREE,
        \}
  let roptions = {
        \ 'patch': options.reverse && options.patch,
        \ 'commit': rhs,
        \ 'filename': filename,
        \ 'worktree': rhs ==# s:WORKTREE,
        \}
  let vertical = matchstr(&diffopt, 'vertical')
  let opener = empty(options.opener)
        \ ? g:gita#command#ui#diff#default_opener
        \ : options.opener
  call gita#command#ui#show#open(extend(options.reverse ? loptions : roptions, {
        \ 'anchor': options.anchor,
        \ 'opener': opener,
        \ 'window': 'diff2_rhs',
        \}))
  call gita#util#diffthis()
  call gita#command#ui#show#open(extend(options.reverse ? roptions : loptions, {
        \ 'anchor': 0,
        \ 'opener': vertical ==# 'vertical'
        \   ? 'leftabove vertical split'
        \   : 'leftabove split',
        \ 'window': 'diff2_lhs',
        \}))
  call gita#util#diffthis()
  call gita#util#select(options.selection)
  diffupdate
endfunction

function! s:get_bufname(options) abort
  let options = extend({
        \ 'patch': 0,
        \ 'cached': 0,
        \ 'reverse': 0,
        \ 'commit': '',
        \ 'filename': '',
        \}, a:options)
  let commit = gita#variable#get_valid_range(options.commit, {
        \ '_allow_empty': 1,
        \})
  let filename = empty(options.filename)
        \ ? ''
        \ : gita#variable#get_valid_filename(options.filename)
  if empty(filename)
    return gita#autocmd#bufname({
          \ 'content_type': 'diff',
          \ 'extra_option': [
          \   options.patch ? 'patch' : '',
          \   !options.patch && options.cached ? 'cached' : '',
          \   !options.patch && options.reverse ? 'reverse' : '',
          \ ],
          \ 'commitish': commit,
          \ 'path': '',
          \})
  else
    return gita#autocmd#bufname({
          \ 'content_type': 'diff',
          \ 'extra_option': [
          \   options.patch ? 'patch' : '',
          \   !options.patch && options.cached ? 'cached' : '',
          \   !options.patch && options.reverse ? 'reverse' : '',
          \ ],
          \ 'commitish': commit,
          \ 'path': filename,
          \})
  endif
endfunction

function! s:on_BufReadCmd(options) abort
  let options = gita#option#cascade('^diff$', a:options, {
        \ 'patch': 0,
        \ 'ignore-space-change': &diffopt =~# 'iwhite',
        \ 'unified': &diffopt =~# 'context:\d\+'
        \   ? matchstr(&diffopt, 'context:\zs\d\+')
        \   : 0,
        \})
  call s:configure_options(options)
  let options['quiet'] = 1
  let result = gita#command#diff#call(options)
  call gita#meta#set('content_type', 'diff')
  call gita#meta#set('options', s:Dict.omit(result.options, [
        \ 'opener', 'selection',
        \]))
  call gita#meta#set('commit', result.commit)
  call gita#meta#set('filename', result.filename)
  call gita#meta#set('filenames', result.filenames)
  call gita#util#buffer#edit_content(
        \ result.content,
        \ gita#autocmd#parse_cmdarg(),
        \)
  if options.patch
    augroup vim_gita_internal_diff_apply_diff
      autocmd! * <buffer>
      autocmd BufWriteCmd <buffer> call s:on_BufWriteCmd()
    augroup END
    setlocal buftype=acwrite
    setlocal noreadonly
  else
    setlocal buftype=nowrite
    setlocal readonly
  endif
  setlocal filetype=diff
endfunction

function! s:on_FileReadCmd(options) abort
  let options = extend({
        \ 'patch': 0,
        \ 'ignore-space-change': &diffopt =~# 'iwhite',
        \ 'unified': &diffopt =~# 'context:\d\+'
        \   ? matchstr(&diffopt, 'context:\zs\d\+')
        \   : 0,
        \}, a:options)
  let options['quiet'] = 1
  let result = gita#command#diff#call(options)
  call gita#util#buffer#read_content(
        \ result.content,
        \ gita#autocmd#parse_cmdarg(),
        \)
endfunction

function! s:on_BufWriteCmd() abort
  " It is only called when PATCH mode is enabled
  try
    let options = gita#meta#get_for('diff', 'options', {})
    let tempfile = tempname()
    try
      call writefile(getline(1, '$'), tempfile)
      call gita#command#apply#call({
            \ 'filenames': [tempfile],
            \ 'cached': 1,
            \ 'unidiff-zero': get(options, 'unified', '') ==# '0',
            \ 'whitespace': 'fix',
            \ 'allow-overlap': 1,
            \ 'recount': 1,
            \})
    finally
      call delete(tempfile)
    endtry
    setlocal nomodified
  catch /^\%(vital: Git[:.]\|vim-gita:\)/
    call gita#util#handle_exception()
  endtry
endfunction

function! s:on_FileWriteCmd() abort
  try
    call gita#throw('Writing a partial content is perhibited')
  catch /^\%(vital: Git[:.]\|vim-gita:\)/
    call gita#util#handle_exception()
  endtry
endfunction


function! gita#command#ui#diff#autocmd(name) abort
  let bufname = expand('<afile>')
  let m = matchlist(bufname, '^gita://[^:\\/]\+:diff:\([^\\/]\+\)[\\/]\(.*\)$')
  if empty(m)
    call gita#throw(printf(
          \ 'A bufname %s does not have required components',
          \ bufname,
          \))
  endif
  let [extra, treeish] = m[1 : 2]
  let [commit, unixpath] = s:GitTerm.split_treeish(treeish, { '_allow_range': 1 })
  let options = gita#util#cascade#get('diff')
  let options.commit = commit
  let options.filename = empty(unixpath) ? '' : s:Git.get_absolute_path(git, unixpath)
  for option_name in split(extra, ':')
    let options[option_name] = 1
  endfor
  call call('s:on_' . a:name, [options])
endfunction

function! gita#command#ui#diff#open(...) abort
  let options = extend({
        \ 'split': 0,
        \}, get(a:000, 0, {}))
  if options.split
    call s:open2(options)
  else
    call s:open1(options)
  endif
endfunction


call gita#util#define_variables('command#ui#diff', {
      \ 'default_opener': '',
      \})
