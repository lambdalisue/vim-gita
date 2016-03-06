let s:V = gita#vital()
let s:Prelude = s:V.import('Prelude')
let s:Dict = s:V.import('Data.Dict')
let s:Path = s:V.import('System.Filepath')
let s:Prompt = s:V.import('Vim.Prompt')
let s:Anchor = s:V.import('Vim.Buffer.Anchor')
let s:StringExt = s:V.import('Data.StringExt')
let s:Git = s:V.import('Git')
let s:WORKTREE = '@@'

function! s:replace_filenames_in_diff(content, filename1, filename2, repl, ...) abort
  let is_windows = get(a:000, 0, s:Prelude.is_windows())
  " replace tempfile1/tempfile2 in the header to a:filename
  "
  "   diff --git a/<tempfile1> b/<tempfile2>
  "   index XXXXXXX..XXXXXXX XXXXXX
  "   --- a/<tempfile1>
  "   +++ b/<tempfile2>
  "
  let src1 = s:StringExt.escape_regex(a:filename1)
  let src2 = s:StringExt.escape_regex(a:filename2)
  if is_windows
    " NOTE:
    " '\' in {content} from 'git diff' are escaped so double escape is required
    " to substitute such path
    " NOTE:
    " escape(src1, '\') cannot be used while other characters such as '.' are
    " already escaped as well
    let src1 = substitute(src1, '\\\\', '\\\\\\\\', 'g')
    let src2 = substitute(src2, '\\\\', '\\\\\\\\', 'g')
  endif
  let repl = (a:filename1 =~# '^/' ? '/' : '') . a:repl
  let content = copy(a:content)
  let content[0] = substitute(content[0], src1, repl, '')
  let content[0] = substitute(content[0], src2, repl, '')
  let content[2] = substitute(content[2], src1, repl, '')
  let content[3] = substitute(content[3], src2, repl, '')
  return content
endfunction

function! s:get_diff_content(git, content, filename) abort
  let tempfile  = tempname()
  let tempfile1 = tempfile . '.index'
  let tempfile2 = tempfile . '.buffer'
  try
    " save contents to temporary files
    let result = gita#command#show#call({
          \ 'commit': '',
          \ 'filename': a:filename,
          \})
    call writefile(result.content, tempfile1)
    call writefile(a:content, tempfile2)
    " create a diff content between index_content and content
    let result = gita#command#diff#call({
          \ 'no-index': 1,
          \ 'filenames': [tempfile1, tempfile2],
          \})
    if empty(result) || empty(result.content) || len(result.content) < 4
      " fail or no differences. Assume that there are no differences
      call s:Prompt.debug(result)
      if &verbose >= 2
        call s:Prompt.debug(result.content)
      endif
      call gita#throw('Attention: No differences are detected')
    endif
    return s:replace_filenames_in_diff(
          \ result.content,
          \ tempfile1,
          \ tempfile2,
          \ s:Path.unixpath(s:Git.get_relative_path(a:git, a:filename)),
          \)
  finally
    call delete(tempfile1)
    call delete(tempfile2)
  endtry
endfunction


function! gita#command#ui#show#BufReadCmd(options) abort
  let options = gita#option#cascade('^show$', a:options, {
        \ 'patch': 0,
        \ 'encoding': '',
        \ 'fileformat': '',
        \ 'bad': '',
        \})
  if options.patch
    " 'patch' mode requires:
    " - INDEX content, naemly 'commit' should be an empty value
    " - file content, namely 'filename' is reqiured
    let options.commit = ''
    let options.filename = gita#variable#get_valid_filename(
          \ get(options, 'filename', ''),
          \)
  endif
  let options['quiet'] = 1
  let result = gita#command#show#call(options)
  call gita#meta#set('content_type', 'show')
  call gita#meta#set('options', s:Dict.omit(result.options, [
        \ 'opener', 'selection',
        \]))
  call gita#meta#set('commit', result.commit)
  call gita#meta#set('filename', result.filename)
  call gita#util#buffer#edit_content(result.content, {
        \ 'encoding': options.encoding,
        \ 'fileformat': options.fileformat,
        \ 'bad': options.bad,
        \})
  if options.patch
    setlocal buftype=acwrite
    setlocal noreadonly
  else
    if empty(result.filename)
      setfiletype git
    endif
    setlocal buftype=nowrite
    setlocal readonly
  endif
endfunction

function! gita#command#ui#show#FileReadCmd(options) abort
  let options = extend({
        \ 'encoding': '',
        \ 'fileformat': '',
        \ 'bad': '',
        \}, a:options)
  let options['quiet'] = 1
  let result = gita#command#show#call(options)
  call gita#util#buffer#read_content(result.content, {
        \ 'encoding': options.encoding,
        \ 'fileformat': options.fileformat,
        \ 'bad': options.bad,
        \})
endfunction

function! gita#command#ui#show#BufWriteCmd(options) abort
  " This autocmd is executed ONLY when the buffer is shown as PATCH mode
  let tempfile = tempname()
  try
    let git = gita#core#get_or_fail()
    let filename = gita#meta#get_for('show', 'filename', '')
    let content  = s:get_diff_content(git, getline(1, '$'), filename)
    call writefile(content, tempfile)
    call gita#command#apply#call({
          \ 'filenames': [tempfile],
          \ 'cached': 1,
          \})
    setlocal nomodified
    diffupdate
  catch /^\%(vital: Git[:.]\|vim-gita:\)/
    call gita#util#handle_exception()
  finally
    call delete(tempfile)
  endtry
endfunction

function! gita#command#ui#show#FileWriteCmd(options) abort
  try
    call gita#throw('Writing a partial content is perhibited')
  catch /^\%(vital: Git[:.]\|vim-gita:\)/
    call gita#util#handle_exception()
  endtry
endfunction

function! gita#command#ui#show#bufname(options) abort
  let options = extend({
        \ 'commit': '',
        \ 'filename': '',
        \ 'patch': 0,
        \ 'worktree': 0,
        \}, a:options)
  if options.worktree || options.commit ==# s:WORKTREE
    if !filereadable(options.filename)
      call gita#throw(
            \ printf(
            \   'A file "%s" could not be found in the working tree',
            \   options.filename,
            \))
    endif
    return s:Path.relpath(gita#variable#get_valid_filename(options.filename))
  endif
  let git = gita#core#get_or_fail()
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

function! gita#command#ui#show#open(...) abort
  let options = extend({
        \ 'anchor': 0,
        \ 'opener': '',
        \ 'window': '',
        \ 'selection': [],
        \}, get(a:000, 0, {}))
  let bufname = gita#command#ui#show#bufname(options)
  if empty(bufname)
    return
  endif
  let opener = empty(options.opener)
        \ ? g:gita#command#ui#show#default_opener
        \ : options.opener
  if options.anchor && s:Anchor.is_available(opener)
    call s:Anchor.focus()
  endif
  try
    let g:gita#var = options
    call gita#util#buffer#open(bufname, {
          \ 'opener': opener,
          \ 'window': options.window,
          \})
  finally
    silent! unlet! g:gita#var
  endtry
  call gita#util#select(options.selection)
endfunction


call gita#util#define_variables('command#ui#show', {
      \ 'default_opener': '',
      \})
