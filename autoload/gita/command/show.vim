let s:V = gita#vital()
let s:Dict = s:V.import('Data.Dict')
let s:StringExt = s:V.import('Data.StringExt')
let s:Path = s:V.import('System.Filepath')
let s:Prompt = s:V.import('Vim.Prompt')
let s:Anchor = s:V.import('Vim.Buffer.Anchor')
let s:Git = s:V.import('Git')
let s:GitInfo = s:V.import('Git.Info')
let s:GitTerm = s:V.import('Git.Term')
let s:GitProcess = s:V.import('Git.Process')
let s:ArgumentParser = s:V.import('ArgumentParser')
let s:WORKTREE = '@'

function! s:pick_available_options(options) abort
  " Note:
  " Personally 'git show' is used only for showing a content of a particular
  " <refspec> so no options are required to be allowed.
  " Let me know or send me a PR if you need some options to be allowed.
  let options = s:Dict.pick(a:options, [])
  return options
endfunction
function! s:get_ancestor_content(git, commit, filename, options) abort
  let [lhs, rhs] = s:GitTerm.split_range(a:commit)
  let lhs = empty(lhs) ? 'HEAD' : lhs
  let rhs = empty(rhs) ? 'HEAD' : rhs
  let commit = s:GitInfo.get_common_ancestor(a:git, lhs, rhs)
  return s:get_revision_content(a:git, commit, a:filename, a:options)
endfunction
function! s:get_revision_content(git, commit, filename, options) abort
  let options = s:pick_available_options(a:options)
  if empty(a:filename)
    let options['object'] = a:commit
  else
    let options['object'] = printf('%s:%s',
          \ a:commit,
          \ gita#get_relative_path(a:git, a:filename),
          \)
  endif
  let result = gita#execute(a:git, 'show', options)
  if result.status
    call s:GitProcess.throw(result.stdout)
  endif
  return result.content
endfunction
function! s:get_diff_content(git, content, filename, options) abort
  let tempfile  = tempname()
  let tempfile1 = tempfile . '.index'
  let tempfile2 = tempfile . '.buffer'
  try
    " save contents to temporary files
    call writefile(
          \ s:get_revision_content(a:git, '', a:filename, a:options),
          \ tempfile1,
          \)
    call writefile(a:content, tempfile2)
    " create a diff content between index_content and content
    let result = gita#command#diff#call({
          \ 'no-index': 1,
          \ 'filenames': [tempfile1, tempfile2],
          \})
    if empty(result) || empty(result.content) || len(result.content) < 4
      " fail or no differences. Assume that there are no differences
      call gita#throw('Attention: No differences are detected')
    endif
    " replace tempfile1/tempfile2 in the header to a:filename
    "
    "   diff --git a/<tempfile1> b/<tempfile2>
    "   index XXXXXXX..XXXXXXX XXXXXX
    "   --- a/<tempfile1>
    "   +++ b/<tempfile2>
    "
    let src1 = s:StringExt.escape_regex(tempfile1)
    let src2 = s:StringExt.escape_regex(tempfile2)
    let repl = (tempfile =~# '^/' ? '/' : '') . s:Path.unixpath(
          \ s:Git.get_relative_path(a:git, a:filename)
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
  " This autocmd is executed ONLY when the buffer is shown as PATCH mode
  let tempfile = tempname()
  try
    let commit = gita#get_meta('commit', '')
    let options = gita#get_meta('options', {})
    let filename = gita#get_meta('filename', '')
    if exists('#BufWritePre')
      doautocmd BufWritePre
    endif
    let git = gita#get_or_fail()
    let content = s:get_diff_content(git, getline(1, '$'), filename, options)
    call writefile(content, tempfile)
    call gita#command#apply#call({
          \ 'filenames': [tempfile],
          \ 'cached': 1,
          \ 'verbose': 1,
          \})
    setlocal nomodified
    if exists('#BufWritePost')
      doautocmd BufWritePost
    endif
    diffupdate
  catch /^\%(vital: Git[:.]\|vim-gita:\)/
    call gita#util#handle_exception()
  finally
    call delete(tempfile)
  endtry
endfunction

function! gita#command#show#bufname(...) abort
  let options = gita#option#init('^show$', get(a:000, 0, {}), {
        \ 'commit': '',
        \ 'filename': '',
        \ 'patch': 0,
        \})
  if options.commit ==# s:WORKTREE
    return gita#variable#get_valid_filename(options.filename)
  endif
  let git = gita#get_or_fail()
  let commit = gita#variable#get_valid_range(options.commit, {
        \ '_allow_empty': 1,
        \})
  let filename = empty(options.filename)
        \ ? ''
        \ : gita#variable#get_valid_filename(options.filename)
  return gita#autocmd#bufname(git, {
        \ 'content_type': 'show',
        \ 'extra_options': [
        \   options.patch ? 'patch' : '',
        \ ],
        \ 'commitish': commit,
        \ 'path': filename,
        \})
endfunction
function! gita#command#show#call(...) abort
  let options = gita#option#init('^show$', get(a:000, 0, {}), {
        \ 'commit': '',
        \ 'filename': '',
        \})
  let git = gita#get_or_fail()
  let commit = gita#variable#get_valid_range(options.commit, {
        \ '_allow_empty': 1,
        \})
  if empty(options.filename)
    let filename = ''
    let content = s:get_revision_content(git, commit, filename, options)
  else
    let filename = gita#variable#get_valid_filename(options.filename)
    if commit =~# '^.\{-}\.\.\..*$'
      let content = s:get_ancestor_content(git, commit, filename, options)
    elseif commit =~# '^.\{-}\.\..*$'
      let commit  = s:GitTerm.split_range(commit)[0]
      let content = s:get_revision_content(git, commit, filename, options)
    else
      let content = s:get_revision_content(git, commit, filename, options)
    endif
  endif
  let result = {
        \ 'commit': commit,
        \ 'filename': filename,
        \ 'content': content,
        \ 'options': options,
        \}
  return result
endfunction
function! gita#command#show#open(...) abort
  let options = extend({
        \ 'anchor': 1,
        \ 'opener': '',
        \ 'selection': [],
        \}, get(a:000, 0, {}))
  let opener = empty(options.opener)
        \ ? g:gita#command#show#default_opener
        \ : options.opener
  let bufname = gita#command#show#bufname(options)
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
function! gita#command#show#read(...) abort
  let options = extend({}, get(a:000, 0, {}))
  let result = gita#command#show#call(options)
  call gita#util#buffer#read_content(result.content)
endfunction
function! gita#command#show#edit(...) abort
  let options = extend({
        \ 'patch': 0,
        \}, get(a:000, 0, {}))
  if options.patch
    " 'patch' mode requires:
    " - INDEX content, naemly 'commit' should be an empty value
    " - file content, namely 'filename' is reqiured
    let options.commit = ''
    let options.filename = gita#variable#get_valid_filename(
          \ get(options, 'filename', ''),
          \)
  endif
  let result = gita#command#show#call(options)
  call gita#set_meta('content_type', 'show')
  call gita#set_meta('options', s:Dict.omit(result.options, [
        \ 'force', 'opener', 'selection',
        \]))
  call gita#set_meta('commit', result.commit)
  call gita#set_meta('filename', result.filename)
  call gita#util#buffer#edit_content(result.content)
  if empty(result.filename)
    setfiletype git
    setlocal buftype=nowrite
    setlocal readonly
  elseif options.patch
    setlocal buftype=acwrite
    augroup vim_gita_internal_show_apply_diff
      autocmd! * <buffer>
      autocmd BufWriteCmd <buffer> call s:on_BufWriteCmd()
    augroup END
    setlocal noreadonly
  else
    setlocal buftype=nowrite
    setlocal readonly
  endif
endfunction

function! s:get_parser() abort
  if !exists('s:parser') || g:gita#develop
    let s:parser = s:ArgumentParser.new({
          \ 'name': 'Gita show',
          \ 'description': 'Show a content of a commit or a file',
          \ 'complete_threshold': g:gita#complete_threshold,
          \})
    call s:parser.add_argument(
          \ '--opener', '-o',
          \ 'A way to open a new buffer such as "edit", "split", etc.', {
          \   'type': s:ArgumentParser.types.value,
          \})
    call s:parser.add_argument(
          \ '--summary', '-s',
          \ 'Show a summary of the repository instead of a file content', {
          \   'conflicts': ['filename'],
          \})
    call s:parser.add_argument(
          \ '--filename', '-f',
          \ 'A filename', {
          \   'complete': function('gita#variable#complete_filename'),
          \   'conflicts': ['summary'],
          \})
    call s:parser.add_argument(
          \ '--worktree', '-w',
          \ 'Open a content of a file in working tree', {
          \   'conflicts': ['summary'],
          \})
    call s:parser.add_argument(
          \ '--selection',
          \ 'A line number or range of the selection', {
          \   'pattern': '^\%(\d\+\|\d\+-\d\+\)$',
          \})
    call s:parser.add_argument(
          \ '--patch',
          \ 'Show a content of a file in PATCH mode. It force to open an INDEX file content',
          \)
    call s:parser.add_argument(
          \ 'commit', [
          \   'A commit which you want to see.',
          \   'If nothing is specified, it show a content of the index.',
          \   'If <commit> is specified, it show a content of the named <commit>.',
          \   'If <commit1>..<commit2> is specified, it show a content of the named <commit1>',
          \   'If <commit1>...<commit2> is specified, it show a content of a common ancestor of commits',
          \], {
          \   'complete': function('gita#variable#complete_commit'),
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
function! gita#command#show#command(...) abort
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
        \ deepcopy(g:gita#command#show#default_options),
        \ options,
        \)
  call gita#command#show#open(options)
endfunction
function! gita#command#show#complete(...) abort
  let parser = s:get_parser()
  return call(parser.complete, a:000, parser)
endfunction

call gita#util#define_variables('command#show', {
      \ 'default_options': {},
      \ 'default_opener': 'edit',
      \})
