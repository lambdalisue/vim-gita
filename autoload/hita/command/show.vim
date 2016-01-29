let s:V = hita#vital()
let s:Dict = s:V.import('Data.Dict')
let s:StringExt = s:V.import('Data.StringExt')
let s:Path = s:V.import('System.Filepath')
let s:Git = s:V.import('Git')
let s:GitTerm = s:V.import('Git.Term')
let s:ArgumentParser = s:V.import('ArgumentParser')
let s:WORKTREE = '@'

function! s:pick_available_options(options) abort
  let options = s:Dict.pick(a:options, [])
  return options
endfunction
function! s:get_ancestor_content(hita, commit, filename, options) abort
  let [lhs, rhs] = s:GitTerm.split_range(a:commit)
  let lhs = empty(lhs) ? 'HEAD' : lhs
  let rhs = empty(rhs) ? 'HEAD' : rhs
  let result = hita#execute(a:hita, 'merge-base', {
        \ 'commit1': lhs,
        \ 'commit2': rhs,
        \})
  if result.status
    call hita#throw(printf(
          \ 'A common ancestor of %s and %s could not be found.',
          \ lhs, rhs,
          \))
  endif
  return s:get_revision_content(a:hita, result.stdout, a:filename, a:options)
endfunction
function! s:get_revision_content(hita, commit, filename, options) abort
  let options = s:pick_available_options(a:options)
  if empty(a:filename)
    let options['object'] = a:commit
  else
    let options['object'] = printf('%s:%s',
          \ a:commit,
          \ hita#get_relative_path(a:hita, a:filename),
          \)
  endif
  let result = hita#execute(a:hita, 'show', options)
  if result.status
    call hita#throw(result.stdout)
  endif
  return result.content
endfunction
function! s:get_diff_content(hita, content, filename, options) abort
  let tempfile = tempname()
  let tempfile1 = tempfile . '.index'
  let tempfile2 = tempfile . '.buffer'
  try
    " save contents to temporary files
    call writefile(
          \ s:get_revision_content(a:hita, '', a:filename, a:options),
          \ tempfile1,
          \)
    call writefile(a:content, tempfile2)
    " create a diff between index_content and content
    let result = hita#command#diff#call({
          \ 'no-index': 1,
          \ 'filenames': [tempfile1, tempfile2],
          \})
    if empty(result) || empty(result.content) || len(result.content) < 4
      " fail or no differences
      return []
    endif
    " replace tempfile1/tempfile2 in HEADER to a:filename
    "
    "   diff --git a/<tempfile1> b/<tempfile2>
    "   index XXXXXXX..XXXXXXX XXXXXX
    "   --- a/<tempfile1>
    "   +++ b/<tempfile2>
    "
    let src1 = s:StringExt.escape_regex(tempfile1)
    let src2 = s:StringExt.escape_regex(tempfile2)
    let repl = (tempfile =~# '^/' ? '/' : '') . s:Path.unixpath(
          \ s:Git.get_relative_path(a:hita, a:filename)
          \)
    let content = result.content
    let content[0] = substitute(content[0], src1, repl, '')
    let content[0] = substitute(content[0], src2, repl, '')
    let content[2] = substitute(content[2], src1, repl, '')
    let content[3] = substitute(content[3], src2, repl, '')
    return content
  finally
    call delete(tempfile1)
    call delete(tempfile2)
  endtry
endfunction

function! s:on_BufWriteCmd() abort
  let commit = hita#get_meta('commit', '')
  let options = hita#get_meta('options', {})
  let filename = hita#get_meta('filename', '')
  if !empty(commit) || empty(filename)
    call hita#util#prompt#warn(join([
          \ 'Partial patching is only available in a INDEX file, namely',
          \ 'a file opened by ":Hita show [--filename={filename}]"',
          \]))
    return
  endif
  silent doautocmd BufWritePre
  try
    let hita = hita#get_or_fail()
    let content = s:get_diff_content(hita, getline(1, '$'), filename, options)
    if empty(content)
      " fail or no difference
      return
    endif
    let tempfile = tempname()
    try
      call writefile(content, tempfile)
      let result = hita#command#apply#call({
            \ 'filenames': [tempfile],
            \ 'cached': 1,
            \ 'verbose': 1,
            \})
    finally
      call delete(tempfile)
    endtry
    if empty(result)
      return
    endif
    call hita#command#show#edit({'force': 1})
    silent doautocmd BufWritePost
    silent diffupdate
  catch /^\%(vital: Git[:.]\|vim-hita\)/
    call hita#util#handle_exception(v:exception)
  endtry
endfunction

function! hita#command#show#bufname(...) abort
  let options = hita#option#init('show', get(a:000, 0, {}), {
        \ 'commit': '',
        \ 'filename': '',
        \})
  if options.commit ==# s:WORKTREE
    return hita#variable#get_valid_filename(options.filename)
  endif

  try
    let hita = hita#get_or_fail()
    let commit = hita#variable#get_valid_range(options.commit, {
          \ '_allow_empty': 1,
          \})
    let filename = empty(options.filename)
          \ ? ''
          \ : hita#variable#get_valid_filename(options.filename)
  catch /^\%(vital:\|vim-hita\)/
    call hita#util#handle_exception(v:exception)
    return
  endtry
  return hita#autocmd#bufname(hita, {
        \ 'content_type': 'show',
        \ 'extra_options': [],
        \ 'commitish': commit,
        \ 'path': filename,
        \})
endfunction
function! hita#command#show#call(...) abort
  let options = hita#option#init('show', get(a:000, 0, {}), {
        \ 'commit': '',
        \ 'filename': '',
        \})
  try
    let hita = hita#get_or_fail()
    let commit = hita#variable#get_valid_range(options.commit, {
          \ '_allow_empty': 1,
          \})
    if empty(options.filename)
      let filename = ''
      let content = s:get_revision_content(hita, commit, filename, options)
    else
      let filename = hita#variable#get_valid_filename(options.filename)
      if commit =~# '^.\{-}\.\.\..*$'
        let content = s:get_ancestor_content(hita, commit, filename, options)
      elseif commit =~# '^.\{-}\.\..*$'
        let commit  = s:GitTerm.split_range(commit)[0]
        let content = s:get_revision_content(hita, commit, filename, options)
      else
        let content = s:get_revision_content(hita, commit, filename, options)
      endif
    endif
    let result = {
          \ 'commit': commit,
          \ 'filename': filename,
          \ 'content': content,
          \}
    return result
  catch /^\%(vital:\|vim-hita\)/
    call hita#util#handle_exception(v:exception)
    return {}
  endtry
endfunction
function! hita#command#show#open(...) abort
  let options = extend({
        \ 'opener': '',
        \}, get(a:000, 0, {}))
  let opener = empty(options.opener)
        \ ? g:hita#command#show#default_opener
        \ : options.opener
  let bufname = hita#command#show#bufname(options)
  if !empty(bufname)
    call hita#util#buffer#open(bufname, {
          \ 'opener': opener,
          \})
    " BufReadCmd will call ...#edit to apply the content
  endif
endfunction
function! hita#command#show#read(...) abort
  let options = extend({}, get(a:000, 0, {}))
  let result = hita#command#show#call(options)
  if empty(result)
    return
  endif
  call hita#util#buffer#read_content(result.content)
endfunction
function! hita#command#show#edit(...) abort
  let options = extend({
        \ 'force': 0,
        \}, get(a:000, 0, {}))
  if options.force || hita#get_meta('content_type', '') !=# 'show'
    " Reload content only when 1) no content exists yet, 2) ! applied to non modified buffer
    let result = hita#command#show#call(options)
    if empty(result)
      return
    endif
    call hita#set_meta('content_type', 'show')
    call hita#set_meta('options', s:Dict.omit(options, ['force']))
    call hita#set_meta('commit', result.commit)
    call hita#set_meta('filename', result.filename)
    call hita#set_meta('content', result.content)
    let commit = result.commit
    let filename = result.filename
    let content = result.content
  else
    let commit = hita#get_meta('commit')
    let filename = hita#get_meta('filename')
    let content = hita#get_meta('content')
  endif
  call hita#util#buffer#edit_content(content)
  if empty(filename)
    setfiletype git
    setlocal buftype=nowrite
    setlocal readonly
  else
    setlocal buftype=acwrite
    augroup vim_gita_internal_show_apply_diff
      autocmd! * <buffer>
      autocmd BufWriteCmd <buffer> call s:on_BufWriteCmd()
    augroup END
    if empty(commit)
      setlocal noreadonly
    else
      setlocal readonly
    endif
  endif
endfunction

function! s:get_parser() abort
  if !exists('s:parser') || g:hita#develop
    let s:parser = s:ArgumentParser.new({
          \ 'name': 'Hita show',
          \ 'description': 'Show a content of a commit or a file',
          \ 'complete_threshold': g:hita#complete_threshold,
          \})
    call s:parser.add_argument(
          \ '--opener', '-o',
          \ 'A way to open a new buffer such as "edit", "split", etc.', {
          \   'type': s:ArgumentParser.types.value,
          \})
    call s:parser.add_argument(
          \ '--summary',
          \ 'Show summary of the repository instead of file content', {
          \   'conflicts': ['filename'],
          \})
    call s:parser.add_argument(
          \ '--filename',
          \ 'A filename', {
          \   'complete': function('hita#variable#complete_filename'),
          \   'conflicts': ['summary'],
          \})
    call s:parser.add_argument(
          \ '--worktree',
          \ 'Open a content of a file in working tree', {
          \   'conflicts': ['summary'],
          \})
    call s:parser.add_argument(
          \ 'commit', [
          \   'A commit which you want to see.',
          \   'If nothing is specified, it show a content of the index.',
          \   'If <commit> is specified, it show a content of the named <commit>.',
          \   'If <commit1>..<commit2> is specified, it show a content of the named <commit1>',
          \   'If <commit1>...<commit2> is specified, it show a content of a common ancestor of commits',
          \], {
          \   'complete': function('hita#variable#complete_commit'),
          \})
    function! s:parser.hooks.post_validate(options) abort
      if has_key(a:options, 'summary')
        let a:options.filename = ''
        unlet a:options.summary
      endif
      if has_key(a:options, 'worktree')
        let a:options.commit = s:WORKTREE
        unlet a:options.worktree
      endif
    endfunction
    call s:parser.hooks.validate()
  endif
  return s:parser
endfunction
function! hita#command#show#command(...) abort
  let parser  = s:get_parser()
  let options = call(parser.parse, a:000, parser)
  if empty(options)
    return
  endif
  call hita#option#assign_commit(options)
  call hita#option#assign_filename(options)
  " extend default options
  let options = extend(
        \ deepcopy(g:hita#command#show#default_options),
        \ options,
        \)
  call hita#command#show#open(options)
endfunction
function! hita#command#show#complete(...) abort
  let parser = s:get_parser()
  return call(parser.complete, a:000, parser)
endfunction

call hita#util#define_variables('command#show', {
      \ 'default_options': {},
      \ 'default_opener': 'edit',
      \})
