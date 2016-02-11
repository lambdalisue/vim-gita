let s:V = gita#vital()
let s:Dict = s:V.import('Data.Dict')
let s:Prompt = s:V.import('Vim.Prompt')
let s:Anchor = s:V.import('Vim.Buffer.Anchor')
let s:GitTerm = s:V.import('Git.Term')
let s:GitProcess = s:V.import('Git.Process')
let s:ArgumentParser = s:V.import('ArgumentParser')

function! s:pick_available_options(options) abort
  " Note:
  " Let me know or send me a PR if you need options not listed below
  let options = s:Dict.pick(a:options, [
        \ 'ignore-submodules',
        \ 'no-index', 'exit-code',
        \ 'U', 'unified',
        \ 'patience',
        \ 'histogram',
        \ 'cached',
        \ 'R', 'reverse',
        \ 'numstat',
        \])
  return options
endfunction
function! s:get_diff_content(git, commit, filenames, options) abort
  let options = s:pick_available_options(a:options)
  " Diff use 'R' instead of 'reverse' so translate
  if !has_key(a:options, 'R') && get(a:options, 'reverse', 0)
    let options['R'] = 1
  endif
  let options = s:Dict.omit(options, ['reverse'])
  let options['no-color'] = 1
  let options['commit'] = a:commit
  if !empty(a:filenames)
    let options['--'] = a:filenames
  endif
  let result = gita#execute(a:git, 'diff', options)
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

function! s:on_BufWriteCmd() abort
  " It is only called when PATCH mode is enabled
  try
    let options = gita#get_meta('options', {})
    if exists('#BufWritePre')
      doautocmd BufWritePre
    endif
    let tempfile = tempname()
    try
      call writefile(getline(1, '$'), tempfile)
      call gita#command#apply#call({
            \ 'quiet': 1,
            \ 'filenames': [tempfile],
            \ 'cached': 1,
            \ 'unidiff-zero': get(options, 'unified', '') ==# '0',
            \ 'whitespace': 'fix',
            \ 'allow-overlap': 1,
            \ 'inaccurate-eof': 1,
            \ 'recount': 1,
            \})
    finally
      call delete(tempfile)
    endtry
    setlocal nomodified
    if exists('#BufWritePost')
      doautocmd BufWritePost
    endif
  catch /^\%(vital: Git[:.]\|vim-gita:\)/
    call gita#util#handle_exception()
  endtry
endfunction

function! gita#command#diff#bufname(...) abort
  let options = gita#option#init('^diff$', get(a:000, 0, {}), {
        \ 'patch': 0,
        \ 'cached': 0,
        \ 'reverse': 0,
        \ 'commit': '',
        \ 'filename': '',
        \})
  let git = gita#get_or_fail()
  let commit = gita#variable#get_valid_range(options.commit, {
        \ '_allow_empty': 1,
        \})
  let filename = empty(options.filename)
        \ ? ''
        \ : gita#variable#get_valid_filename(options.filename)
  if empty(filename)
    return gita#autocmd#bufname(git, {
          \ 'content_type': 'diff',
          \ 'extra_options': [
          \   options.patch ? 'patch' : '',
          \   !options.patch && options.cached ? 'cached' : '',
          \   !options.patch && options.reverse ? 'reverse' : '',
          \ ],
          \ 'commitish': commit,
          \ 'path': '',
          \})
  else
    return gita#autocmd#bufname(git, {
          \ 'content_type': 'diff',
          \ 'extra_options': [
          \   options.patch ? 'patch' : '',
          \   !options.patch && options.cached ? 'cached' : '',
          \   !options.patch && options.reverse ? 'reverse' : '',
          \ ],
          \ 'commitish': commit,
          \ 'path': filename,
          \})
  endif
endfunction
function! gita#command#diff#call(...) abort
  let options = gita#option#init('^diff$', get(a:000, 0, {}), {
        \ 'cached': 0,
        \ 'reverse': 0,
        \ 'commit': '',
        \ 'filename': '',
        \ 'filenames': [],
        \})
  let git = gita#get_or_fail()
  let commit = gita#variable#get_valid_range(options.commit, {
        \ '_allow_empty': 1,
        \})
  if empty(options.filenames)
    let filenames = []
  else
    let filenames = map(
          \ copy(options.filenames),
          \ 'gita#variable#get_valid_filename(v:val)'
          \)
  endif
  if !empty(options.filename)
    call insert(
          \ filenames,
          \ gita#variable#get_valid_filename(options.filename)
          \)
    " remove duplicate filenames
    let filenames = uniq(filenames)
  endif
  let content = s:get_diff_content(git, commit, filenames, options)
  let result = {
        \ 'commit': commit,
        \ 'filename': empty(filenames) ? '' : filenames[0],
        \ 'filenames': filenames,
        \ 'content': content,
        \ 'options': options,
        \}
  return result
endfunction
function! gita#command#diff#open(...) abort
  let options = extend({
        \ 'anchor': 1,
        \ 'opener': '',
        \ 'selection': [],
        \}, get(a:000, 0, {}))
  if empty(options.opener)
    let content_type = gita#get_meta('content_type', '')
    if content_type =~# '^blame-\%(navi\|view\)$'
      let opener = 'tabedit'
    else
      let opener = g:gita#command#diff#default_opener
    endif
  else
    let opener = options.opener
  endif
  let bufname = gita#command#diff#bufname(options)
  if !empty(bufname)
    if options.anchor
      call s:Anchor.focus()
    endif
    call gita#util#buffer#open(bufname, {
          \ 'opener': opener,
          \})
    " BufReadCmd will call ...#edit to apply the content
    call gita#util#select(options.selection)
  endif
endfunction
function! gita#command#diff#read(...) abort
  let options = extend({}, get(a:000, 0, {}))
  let result = gita#command#diff#call(options)
  call gita#util#buffer#read_content(result.content)
endfunction
function! gita#command#diff#edit(...) abort
  let options = extend({
        \ 'patch': 0,
        \ 'force': 0,
        \}, get(a:000, 0, {}))
  if options.patch
    " 'patch' mode requires:
    " - Existence of INDEX, namely no commit or --cached
    let commit = get(options, 'commit', '')
    if empty(commit)
      " INDEX vs HEAD
      let options.cached = 0
      let options.reverse = 0
    elseif commit =~# '^.\{-}\.\.\.?.*$'
      " RANGE is not allowed
      call gita#throw(printf(
            \ 'A commit range "%s" is not allowed for PATCH mode.',
            \ commit,
            \))
    else
      " COMMIT vs INDEX
      let options.cached = 1
      let options.reverse = 1
    endif
  endif
  let result = gita#command#diff#call(options)
  call gita#set_meta('content_type', 'diff')
  call gita#set_meta('options', s:Dict.omit(result.options, [
        \ 'force', 'opener', 'selection',
        \]))
  call gita#set_meta('commit', result.commit)
  call gita#set_meta('filename', result.filename)
  call gita#set_meta('filenames', result.filenames)
  call gita#util#buffer#edit_content(result.content)
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
  setfiletype diff
endfunction
function! gita#command#diff#open2(...) abort
  let options = extend({
        \ 'patch': 0,
        \ 'cached': 0,
        \ 'reverse': 0,
        \ 'commit': '',
        \ 'filename': '',
        \ 'anchor': 1,
        \ 'opener': '',
        \ 'split': '',
        \ 'selection': [],
        \}, get(a:000, 0, {}))
  if options.patch
    " 'patch' mode requires:
    " - Existence of INDEX, namely no commit or --cached
    let commit = get(options, 'commit', '')
    if empty(commit)
      " INDEX vs HEAD
      let options.cached = 0
      let options.reverse = 0
    elseif commit =~# '^.\{-}\.\.\.?.*$'
      " RANGE is not allowed
      call gita#throw(printf(
            \ 'A commit range "%s" is not allowed for PATCH mode.',
            \ commit,
            \))
    else
      " COMMIT vs INDEX
      let options.cached = 1
      let options.reverse = 1
    endif
  endif
  let commit = gita#variable#get_valid_range(options.commit, {
        \ '_allow_empty': 1,
        \})
  let filename = empty(options.filename) ? '%' : options.filename
  let filename = gita#variable#get_valid_filename(filename)
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
  let lbufname = gita#command#show#bufname({
        \ 'patch': !options.reverse && options.patch,
        \ 'commit': lhs,
        \ 'filename': filename,
        \})
  let rbufname = rhs ==# WORKTREE ? filename : gita#command#show#bufname({
        \ 'patch': options.reverse && options.patch,
        \ 'commit': rhs,
        \ 'filename': filename,
        \})
  if empty(options.opener)
    let content_type = gita#get_meta('content_type', '')
    if content_type =~# '^blame-\%(navi\|view\)$'
      let opener = 'tabedit'
    else
      let opener = g:gita#command#diff#default_opener
    endif
  else
    let opener = options.opener
  endif
  let split = empty(options.split)
        \ ? g:gita#command#diff#default_split
        \ : options.split
  " NOTE:
  " Place main contant to visually rightbelow and focus
  if options.anchor
    call s:Anchor.focus()
  endif
  if !options.reverse
    let rresult = gita#util#buffer#open(rbufname, {
          \ 'group': 'diff_rhs',
          \ 'opener': opener,
          \})
    call gita#util#diffthis()
    let lresult = gita#util#buffer#open(lbufname, {
          \ 'opener': split ==# 'vertical'
          \   ? 'leftabove vertical split'
          \   : 'leftabove split',
          \})
    call gita#util#diffthis()
    diffupdate
    execute printf('keepjump %dwincmd w', bufwinnr(
          \ options.patch ? lresult.bufnum : rresult.bufnum
          \))
    call gita#util#select(options.selection)
  else
    let rresult = gita#util#buffer#open(rbufname, {
          \ 'group': 'diff_lhs',
          \ 'opener': opener,
          \})
    call gita#util#diffthis()
    let lresult = gita#util#buffer#open(lbufname, {
          \ 'opener': split ==# 'vertical'
          \   ? 'rightbelow vertical split'
          \   : 'rightbelow split',
          \})
    call gita#util#diffthis()
    diffupdate
    execute printf('keepjump %dwincmd w', bufwinnr(
          \ options.patch ? rresult.bufnum : lresult.bufnum
          \))
    call gita#util#select(options.selection)
  endif
endfunction

function! s:get_parser() abort
  if !exists('s:parser') || g:gita#develop
    let s:parser = s:ArgumentParser.new({
          \ 'name': 'Gita diff',
          \ 'description': 'Show a diff content of a commit or files',
          \ 'complete_unknown': function('gita#variable#complete_filename'),
          \ 'unknown_description': 'filename',
          \ 'complete_threshold': g:gita#complete_threshold,
          \})
    call s:parser.add_argument(
          \ '--opener', '-o',
          \ 'A way to open a new buffer such as "edit", "split", etc.', {
          \   'type': s:ArgumentParser.types.value,
          \})
    call s:parser.add_argument(
          \ '--repository', '-r',
          \ 'Show a diff of the repository instead of a file content',
          \)
    call s:parser.add_argument(
          \ '--cached', '-c',
          \ 'Compare the changes you staged for the next commit rather than working tree', {
          \   'conflicts': ['--patch'],
          \})
    call s:parser.add_argument(
          \ '--reverse', '-R',
          \ 'Show a diff content reversely', {
          \   'conflicts': ['--patch'],
          \})
    call s:parser.add_argument(
          \ '--split', '-s',
          \ 'Open two buffer to compare by vimdiff rather than to open a single diff file', {
          \   'on_default': g:gita#command#diff#default_split,
          \   'choices': ['vertical', 'horizontal'],
          \})
    call s:parser.add_argument(
          \ '--selection',
          \ 'A line number or range of the selection', {
          \   'pattern': '^\%(\d\+\|\d\+-\d\+\)$',
          \})
    call s:parser.add_argument(
          \ '--patch',
          \ 'Diff a content in PATCH mode. It automatically assign --cached/--reverse correctly', {
          \   'conflicts': ['--cached', '--reverse'],
          \})
    call s:parser.add_argument(
          \ 'commit', [
          \   'A commit which you want to diff.',
          \   'If nothing is specified, it diff a content between an index and working tree or HEAD when --cached is specified.',
          \   'If <commit> is specified, it diff a content between the named <commit> and working tree or an index.',
          \   'If <commit1>..<commit2> is specified, it diff a content between the named <commit1> and <commit2>',
          \   'If <commit1>...<commit2> is specified, it diff a content of a common ancestor of commits and <commit2>',
          \ ], {
          \   'complete': function('gita#variable#complete_commit'),
          \})
    " TODO: Add more arguments
    function! s:parser.hooks.post_validate(options) abort
      if has_key(a:options, 'repository')
        let a:options.filename = ''
        unlet a:options.repository
      endif
    endfunction
    call s:parser.hooks.validate()
  endif
  return s:parser
endfunction
function! gita#command#diff#command(...) abort
  let parser  = s:get_parser()
  let options = call(parser.parse, a:000, parser)
  if empty(options)
    return
  endif
  call gita#option#assign_commit(options)
  call gita#option#assign_filename(options)
  call gita#option#assign_selection(options)
  " extend default options
  let options = extend(
        \ deepcopy(g:gita#command#diff#default_options),
        \ options,
        \)
  if empty(get(options, 'split'))
    call gita#command#diff#open(options)
  else
    call gita#command#diff#open2(options)
  endif
endfunction
function! gita#command#diff#complete(...) abort
  let parser = s:get_parser()
  return call(parser.complete, a:000, parser)
endfunction

call gita#util#define_variables('command#diff', {
      \ 'default_options': {},
      \ 'default_opener': 'edit',
      \ 'default_split': 'vertical',
      \})
