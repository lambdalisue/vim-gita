let s:V = gita#vital()
let s:Prelude = s:V.import('Prelude')
let s:Path = s:V.import('System.Filepath')
let s:Dict = s:V.import('Data.Dict')
let s:Git = s:V.import('Git')
let s:GitInfo = s:V.import('Git.Info')
let s:GitTerm = s:V.import('Git.Term')

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

function! s:build_bufname(options) abort
  let options = extend({
        \ 'commit': '',
        \ 'filename': '',
        \ 'patch': 0,
        \ 'cached': 0,
        \ 'reverse': 0,
        \}, a:options)
  let git = gita#core#get_or_fail()
  let treeish = printf('%s:%s',
        \ options.commit,
        \ s:Path.unixpath(s:Git.get_relative_path(git, options.filename)),
        \)
  return gita#content#build_bufname('diff', {
        \ 'extra_options': [
        \   options.patch ? 'patch' : '',
        \   !options.patch && options.cached ? 'cached' : '',
        \   !options.patch && options.reverse ? 'reverse' : '',
        \ ],
        \ 'treeish': treeish,
        \})
endfunction

function! s:parse_bufname(bufinfo) abort
  let m = matchlist(a:bufinfo.treeish, '^\([^:]*\)\%(:\(.*\)\)\?$')
  if empty(m)
    call gita#throw(printf(
          \ 'A treeish part of a buffer name "%s" does not follow "%s" pattern',
          \ a:bufinfo.bufname, '<rev>:<filename>',
          \))
  endif
  let git = gita#core#get_or_fail()
  let a:bufinfo.commit = m[1]
  let a:bufinfo.filename = s:Path.realpath(s:Git.get_absolute_path(git, m[2]))
  return a:bufinfo
endfunction

function! s:execute_command(options) abort
  let git = gita#core#get_or_fail()
  if a:options.commit =~# '^.\{-}\.\.\..\{-}$'
    " git diff <lhs>...<rhs> : <lhs>...<rhs> vs <rhs>
    let [lhs, rhs] = s:GitTerm.split_range(a:options.commit)
    let lhs = empty(lhs) ? 'HEAD' : lhs
    let rhs = empty(rhs) ? 'HEAD' : rhs
    let lhs = s:GitInfo.find_common_ancestor(git, lhs, rhs)
    let a:options.commit = lhs . '..' . rhs
  endif
  let args = gita#process#args_from_options(a:options, {
        \ 'unified': 1,
        \ 'minimal': 1,
        \ 'patience': 1,
        \ 'histogram': 1,
        \ 'diff-algorithm': 1,
        \ 'submodule': 1,
        \ 'word-diff-regex': 1,
        \ 'no-renames': 1,
        \ 'full-index': 1,
        \ 'binary': 1,
        \ 'abbrev': 1,
        \ 'B': 1,
        \ 'M': 1,
        \ 'C': 1,
        \ 'find-copies-harder': 1,
        \ 'irreversible-delete': 1,
        \ 'l': 1,
        \ 'diff-filter': 1,
        \ 'S': 1,
        \ 'G': 1,
        \ 'pickaxe-all': 1,
        \ 'O': 1,
        \ 'R': 1,
        \ 'relative': 1,
        \ 'text': 1,
        \ 'ignore-space-at-eol': 1,
        \ 'ignore-space-change': 1,
        \ 'ignore-all-space': 1,
        \ 'ignore-blank-lines': 1,
        \ 'inter-hunk-context': 1,
        \ 'function-context': 1,
        \ 'ignore-submodules': 1,
        \ 'src-prefix': 1,
        \ 'dst-prefix': 1,
        \ 'no-prefix': 1,
        \ 'numstat': 1,
        \ 'no-index': 1,
        \ 'cached': 1,
        \})
  let args = [
        \ 'diff',
        \ '--no-color',
        \] + args + [
        \ a:options.commit,
        \ '--',
        \ a:options.filename,
        \]
  return gita#process#execute(git, args, {
        \ 'quiet': 1,
        \ 'encode_output': 0,
        \})
endfunction

function! s:on_BufReadCmd(options) abort
  call gita#util#doautocmd('BufReadPre')
  let options = gita#option#cascade('^diff$', a:options, {
        \ 'commit': '',
        \ 'filename': '',
        \ 'patch': 0,
        \ 'ignore-space-change': &diffopt =~# 'iwhite',
        \ 'unified': &diffopt =~# 'context:\d\+'
        \   ? matchstr(&diffopt, 'context:\zs\d\+')
        \   : 0,
        \})
  call s:configure_options(options)
  let content = s:execute_command(options)
  call gita#meta#set('content_type', 'diff')
  call gita#meta#set('options', options)
  call gita#meta#set('commit', options.commit)
  call gita#meta#set('filename', options.filename)
  call gita#util#buffer#edit_content(
        \ content,
        \ gita#util#buffer#parse_cmdarg(),
        \)
  call gita#util#observer#attach()
  if options.patch
    setlocal buftype=acwrite
    setlocal noreadonly
  else
    setlocal buftype=nowrite
    setlocal readonly
  endif
  setlocal filetype=diff
  call gita#util#doautocmd('BufReadPost')
endfunction

function! s:on_FileReadCmd(options) abort
  let options = extend({
        \ 'commit': '',
        \ 'filename': '',
        \ 'ignore-space-change': &diffopt =~# 'iwhite',
        \ 'unified': &diffopt =~# 'context:\d\+'
        \   ? matchstr(&diffopt, 'context:\zs\d\+')
        \   : 0,
        \}, a:options)
  call s:configure_options(options)
  let content = s:execute_command(options)
  call gita#util#buffer#read_content(
        \ content,
        \ gita#util#buffer#parse_cmdarg(),
        \)
endfunction

function! s:on_BufWriteCmd(options) abort
  call gita#util#doautocmd('BufWritePre')
  try
    let options = gita#meta#get_for('^diff$', 'options', {})
    let tempfile = tempname()
    try
      call writefile(getline(1, '$'), tempfile)
      let args = [
            \ 'apply',
            \ '--cached',
            \ '--whitespace=fix',
            \ '--allow-overlap',
            \ '--recount',
            \ get(options, 'unified', '') ==# '0' ? '--unidiff-zero' : '',
            \ '--',
            \ tempfile,
            \]
      let git = gita#core#get_or_fail()
      call gita#process#execute(git, args, { 'quiet': 1 })
    finally
      call delete(tempfile)
    endtry
    setlocal nomodified
    call gita#util#doautocmd('User', 'GitaStatusModified')
    call gita#util#doautocmd('BufWritePost')
  catch /^\%(vital: Git[:.]\|vim-gita:\)/
    call gita#util#handle_exception()
  endtry
endfunction

function! s:on_FileWriteCmd(options) abort
  call gita#throw('Writing a partial content is perhibited')
endfunction

function! s:open1(options) abort
  let options = extend({
        \ 'opener': '',
        \ 'window': '',
        \ 'selection': [],
        \}, a:options)
  let bufname = s:build_bufname(options)
  let opener = empty(options.opener)
        \ ? g:gita#content#diff#default_opener
        \ : options.opener
  call gita#util#cascade#set('diff', options)
  call gita#util#buffer#open(bufname, {
        \ 'opener': opener,
        \ 'window': options.window,
        \ 'selection': options.selection,
        \})
endfunction

function! s:open2(options) abort
  let WORKTREE = '@@'
  let options = extend({
        \ 'patch': 0,
        \ 'cached': 0,
        \ 'reverse': 0,
        \ 'commit': '',
        \ 'filename': '',
        \ 'opener': '',
        \ 'selection': [],
        \}, a:options)
  call s:configure_options(options)
  let commit = options.commit
  let filename = empty(options.filename) ? gita#meta#expand('%') : options.filename
  if empty(commit)
    " git diff          : INDEX vs TREE
    " git diff --cached :  HEAD vs INDEX
    let lhs = options.cached ? 'HEAD' : ''
    let rhs = options.cached ? '' : WORKTREE
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
    let rhs = options.cached ? '' : WORKTREE
  endif
  let loptions = {
        \ 'patch': !options.reverse && options.patch,
        \ 'commit': lhs,
        \ 'filename': filename,
        \ 'worktree': lhs ==# WORKTREE,
        \}
  let roptions = {
        \ 'patch': options.reverse && options.patch,
        \ 'commit': rhs,
        \ 'filename': filename,
        \ 'worktree': rhs ==# WORKTREE,
        \}
  let vertical = matchstr(&diffopt, 'vertical')
  let opener = empty(options.opener)
        \ ? g:gita#content#diff#default_opener
        \ : options.opener
  call gita#content#show#open(extend(options.reverse ? loptions : roptions, {
        \ 'opener': opener,
        \ 'window': 'diff2_rhs',
        \ 'selection': options.selection,
        \}))
  call gita#util#diffthis()
  call gita#content#show#open(extend(options.reverse ? roptions : loptions, {
        \ 'opener': vertical ==# 'vertical'
        \   ? 'leftabove vertical split'
        \   : 'leftabove split',
        \ 'window': 'diff2_lhs',
        \ 'selection': options.selection,
        \}))
  call gita#util#diffthis()
  diffupdate
endfunction

function! gita#content#diff#open(options) abort
  let options = extend({
        \ 'split': 0,
        \}, a:options)
  if options.split
    call s:open2(options)
  else
    call s:open1(options)
  endif
endfunction

function! gita#content#diff#autocmd(name, bufinfo) abort
  let bufinfo = s:parse_bufname(a:bufinfo)
  let options = extend(gita#util#cascade#get('diff'), {
        \ 'commit': bufinfo.commit,
        \ 'filename': bufinfo.filename,
        \})
  for attribute in bufinfo.extra_options
    let options[attribute] = 1
  endfor
  call call('s:on_' . a:name, [options])
endfunction

call gita#define_variables('content#diff', {
      \ 'default_opener': 'edit',
      \})
