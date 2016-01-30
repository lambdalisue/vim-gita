let s:V = hita#vital()
let s:Dict = s:V.import('Data.Dict')
let s:Prompt = s:V.import('Vim.Prompt')
let s:GitTerm = s:V.import('Git.Term')
let s:GitProcess = s:V.import('Git.Process')
let s:ArgumentParser = s:V.import('ArgumentParser')

function! s:pick_available_options(options) abort
  let options = s:Dict.pick(a:options, [
        \ 'ignore-submodules',
        \ 'no-prefix', 'no-index', 'exit-code',
        \ 'U', 'unified', 'minimal',
        \ 'patience', 'histogram', 'diff-algorithm',
        \ 'cached',
        \])
  return options
endfunction
function! s:get_diff_content(git, commit, filenames, options) abort
  let options = s:pick_available_options(a:options)
  let options['no-color'] = 1
  let options['commit'] = a:commit
  if !has_key(options, 'R')
    let options['R'] = get(a:options, 'reverse', 0)
  endif
  if !empty(a:filenames)
    let options['--'] = a:filenames
  endif
  let result = hita#execute(a:git, 'diff', options)
  if get(options, 'no-index') || get(options, 'exit-code')
    " NOTE:
    " --no-index force --exit-code option.
    " --exit-code mean that the program exits with 1 if there were differences
    " and 0 means no differences
    return result.content
  elseif result.status
    call s:GitProcess.throw(result.stdout)
  endif
  return result.content
endfunction
function! s:is_patchable(commit, options) abort
  let options = extend({
        \ 'cached': 0,
        \ 'reverse': 0,
        \}, a:options)
  if empty(a:commit) && !options.cached && !options.reverse
    " Diff between TREE <> INDEX
    return 1
  elseif options.cached && options.reverse
    " Diff between {ANY} <> INDEX
    return 1
  endif
  return 0
endfunction

function! s:on_BufWriteCmd() abort
  try
    let commit = hita#get_meta('commit', '')
    let options = hita#get_meta('options', {})
    if !s:is_patchable(commit, options)
      call hita#throw(
            \ 'Attention:',
            \ 'Patching diff is only available when diff was produced',
            \ 'by ":Hita diff [-- {filename}...]" or',
            \ '":Hita diff --cached --reverse [{commit}] [-- {filename}...]"',
            \)
      return
    endif
    if exists('#BufWritePre')
      doautocmd BufWritePre
    endif
    let tempfile = tempname()
    try
      call writefile(getline(1, '$'), tempfile)
      call hita#command#apply#call({
            \ 'filenames': [tempfile],
            \ 'cached': 1,
            \ 'verbose': 1,
            \ 'unidiff-zero': get(options, 'unified', '') ==# '0',
            \ 'recount': 1,
            \ 'whitespace': 'fix',
            \})
    finally
      call delete(tempfile)
    endtry
    call hita#command#diff#edit({'force': 1})
    if exists('#BufWritePost')
      doautocmd BufWritePost
    endif
  catch /^\%(vital: Git[:.]\|vim-hita:\)/
    call hita#util#handle_exception()
  endtry
endfunction

function! hita#command#diff#bufname(...) abort
  let options = hita#option#init('^diff$', get(a:000, 0, {}), {
        \ 'cached': 0,
        \ 'reverse': 0,
        \ 'commit': '',
        \ 'filenames': [],
        \})
  let git = hita#get_or_fail()
  let commit = hita#variable#get_valid_range(options.commit, {
        \ '_allow_empty': 1,
        \})
  if !empty(options.filenames)
    let filenames = map(
          \ copy(options.filenames),
          \ 'hita#variable#get_valid_filename(v:val)',
          \)
  else
    let filenames = []
  endif
  if len(filenames) == 1
    return hita#autocmd#bufname(git, {
          \ 'content_type': 'diff',
          \ 'extra_options': [
          \   options.cached ? 'cached' : '',
          \   options.reverse ? 'reverse' : '',
          \ ],
          \ 'commitish': commit,
          \ 'path': filenames[0],
          \})
  else
    return hita#autocmd#bufname(git, {
          \ 'content_type': 'diff',
          \ 'extra_options': [
          \   options.cached ? 'cached' : '',
          \   options.reverse ? 'reverse' : '',
          \ ],
          \ 'commitish': commit,
          \ 'path': '',
          \})
  endif
endfunction
function! hita#command#diff#call(...) abort
  let options = hita#option#init('^diff$', get(a:000, 0, {}), {
        \ 'cached': 0,
        \ 'reverse': 0,
        \ 'commit': '',
        \ 'filenames': [],
        \})
  let git = hita#get_or_fail()
  let commit = hita#variable#get_valid_range(options.commit, {
        \ '_allow_empty': 1,
        \})
  if !empty(options.filenames)
    let filenames = map(
          \ copy(options.filenames),
          \ 'hita#variable#get_valid_filename(v:val)',
          \)
  else
    let filenames = []
  endif
  let content = s:get_diff_content(git, commit, filenames, options)
  let result = {
        \ 'commit': commit,
        \ 'filenames': filenames,
        \ 'content': content,
        \}
  return result
endfunction
function! hita#command#diff#open(...) abort
  let options = extend({
        \ 'opener': '',
        \}, get(a:000, 0, {}))
  let opener = empty(options.opener)
        \ ? g:hita#command#diff#default_opener
        \ : options.opener
  let bufname = hita#command#diff#bufname(options)
  if !empty(bufname)
    call hita#util#buffer#open(bufname, {
          \ 'opener': opener,
          \})
    " BufReadCmd will call ...#edit to apply the content
  endif
endfunction
function! hita#command#diff#read(...) abort
  let options = extend({}, get(a:000, 0, {}))
  let result = hita#command#diff#call(options)
  call hita#util#buffer#read_content(result.content)
endfunction
function! hita#command#diff#edit(...) abort
  let options = extend({
        \ 'force': 0,
        \}, get(a:000, 0, {}))
  let result = hita#command#diff#call(options)
  call hita#set_meta('content_type', 'diff')
  call hita#set_meta('options', s:Dict.omit(options, ['force']))
  call hita#set_meta('commit', result.commit)
  call hita#set_meta('filename', len(result.filenames) == 1 ? result.filenames[0] : '')
  call hita#set_meta('filenames', result.filenames)
  call hita#set_meta('content', result.content)
  call hita#util#buffer#edit_content(result.content)
  augroup vim_gita_internal_diff_apply_diff
    autocmd! * <buffer>
    autocmd BufWriteCmd <buffer> call s:on_BufWriteCmd()
  augroup END
  setfiletype diff
  if s:is_patchable(result.commit, options)
    setlocal noreadonly
  else
    setlocal readonly
  endif
  setlocal buftype=acwrite
endfunction
function! hita#command#diff#open2(...) abort
  let options = extend({
        \ 'cached': 0,
        \ 'reverse': 0,
        \ 'commit': '',
        \ 'filenames': [],
        \ 'opener': '',
        \ 'split': '',
        \}, get(a:000, 0, {}))
  if len(options.filenames) > 1
    call hita#throw(
          \ 'Warning: Hita diff --split cannot handle multiple filenames',
          \)
  endif
  let git = hita#get_or_fail()
  let commit = hita#variable#get_valid_range(options.commit, {
        \ '_allow_empty': 1,
        \})
  let filename = empty(options.filenames) ? '%' : options.filenames[0]
  let filename = hita#variable#get_valid_filename(filename)
  let WORKTREE = '@'  " @ is not valid commit thus
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
  let lbufname = lhs ==# WORKTREE
        \ ? filename
        \ : hita#command#show#bufname({'commit': lhs, 'filename': filename})
  let rbufname = rhs ==# WORKTREE
        \ ? filename
        \ : hita#command#show#bufname({'commit': rhs, 'filename': filename})
  let opener = empty(options.opener)
        \ ? g:hita#command#diff#default_opener
        \ : options.opener
  let split = empty(options.split)
        \ ? g:hita#command#diff#default_split
        \ : options.split
  " NOTE:
  " Place main contant to visually rightbelow and focus
  if !options.reverse
    let rresult = hita#util#buffer#open(rbufname, {
          \ 'group': 'diff_rhs',
          \ 'opener': opener,
          \})
    diffthis
    let lresult = hita#util#buffer#open(lbufname, {
          \ 'group': 'diff_lhs',
          \ 'opener': split ==# 'vertical'
          \   ? 'leftabove vertical split'
          \   : 'leftabove split',
          \})
    diffthis
    diffupdate
    execute printf('keepjump %dwincmd w', bufwinnr(lresult.bufnum))
    keepjump normal! zM
    execute printf('keepjump %dwincmd w', bufwinnr(rresult.bufnum))
    keepjump normal! zM
  else
    let rresult = hita#util#buffer#open(rbufname, {
          \ 'group': 'diff_rhs',
          \ 'opener': opener,
          \})
    diffthis
    let lresult = hita#util#buffer#open(lbufname, {
          \ 'group': 'diff_lhs',
          \ 'opener': split ==# 'vertical'
          \   ? 'rightbelow vertical split'
          \   : 'rightbelow split',
          \})
    diffthis
    diffupdate
    execute printf('keepjump %dwincmd w', bufwinnr(rresult.bufnum))
    keepjump normal! zM
    execute printf('keepjump %dwincmd w', bufwinnr(lresult.bufnum))
    keepjump normal! zM
  endif
endfunction

function! s:get_parser() abort
  if !exists('s:parser') || g:hita#develop
    let s:parser = s:ArgumentParser.new({
          \ 'name': 'Hita diff',
          \ 'description': 'Show a diff content of a commit or files',
          \ 'complete_unknown': function('hita#variable#complete_filename'),
          \ 'unknown_description': 'filenames',
          \ 'complete_threshold': g:hita#complete_threshold,
          \})
    call s:parser.add_argument(
          \ '--opener', '-o',
          \ 'A way to open a new buffer such as "edit", "split", etc.', {
          \   'type': s:ArgumentParser.types.value,
          \})
    call s:parser.add_argument(
          \ '--cached',
          \ 'Compare the changes you staged for the next commit', {
          \})
    call s:parser.add_argument(
          \ '--reverse',
          \ 'reverse', {
          \})
    call s:parser.add_argument(
          \ '--split',
          \ 'Open two buffer to compare rather than to open a diff file', {
          \   'on_default': g:hita#command#diff#default_split,
          \   'choices': ['vertical', 'horizontal'],
          \})
    call s:parser.add_argument(
          \ 'commit',
          \ 'A commit', {
          \   'complete': function('hita#variable#complete_commit'),
          \})
    " TODO: Add more arguments
  endif
  return s:parser
endfunction
function! hita#command#diff#command(...) abort
  let parser  = s:get_parser()
  let options = call(parser.parse, a:000, parser)
  if empty(options)
    return
  endif
  call hita#option#assign_commit(options)
  if !empty(options.__unknown__)
    let options.filenames = options.__unknown__
  endif
  " extend default options
  let options = extend(
        \ deepcopy(g:hita#command#diff#default_options),
        \ options,
        \)
  if empty(get(options, 'split', ''))
    call hita#command#diff#open(options)
  else
    call hita#option#assign_filename(options)
    call hita#command#diff#open2(options)
  endif
endfunction
function! hita#command#diff#complete(...) abort
  let parser = s:get_parser()
  return call(parser.complete, a:000, parser)
endfunction

call hita#util#define_variables('command#diff', {
      \ 'default_options': {},
      \ 'default_opener': 'edit',
      \ 'default_split': 'vertical',
      \})
