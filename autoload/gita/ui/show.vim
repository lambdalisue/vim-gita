let s:V = gita#vital()
let s:Prelude = s:V.import('Prelude')
let s:Dict = s:V.import('Data.Dict')
let s:Path = s:V.import('System.Filepath')
let s:Prompt = s:V.import('Vim.Prompt')
let s:Git = s:V.import('Git')
let s:GitTerm = s:V.import('Git.Term')
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
  let src1 = s:Prelude.escape_pattern(a:filename1)
  let src2 = s:Prelude.escape_pattern(a:filename2)
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
          \ 'quiet': 1,
          \ 'commit': '',
          \ 'filename': a:filename,
          \})
    call writefile(result.content, tempfile1)
    call writefile(a:content, tempfile2)
    " create a diff content between index_content and content
    let result = gita#command#diff#call({
          \ 'quiet': 1,
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

function! s:get_bufname(...) abort
  let options = extend({
        \ 'commit': '',
        \ 'filename': '',
        \ 'patch': 0,
        \ 'ancestors': 0,
        \ 'ours': 0,
        \ 'theirs': 0,
        \ 'worktree': 0,
        \}, get(a:000, 0, {}))
  let git = gita#core#get_or_fail()
  if options.worktree || options.commit ==# s:WORKTREE
    if !filereadable(options.filename)
      call gita#throw(
            \ printf(
            \   'A file "%s" could not be found in the working tree',
            \   options.filename,
            \))
    endif
    return gita#variable#get_valid_filename(git, options.filename)
  endif
  if options.ancestors || options.ours || options.theirs
    let commit = ''
  else
    let commit = gita#variable#get_valid_range(git, options.commit, {
          \ '_allow_empty': 1,
          \})
  endif
  let filename = empty(options.filename)
        \ ? ''
        \ : gita#variable#get_valid_filename(git, options.filename)
  return gita#autocmd#bufname({
        \ 'content_type': 'show',
        \ 'extra_option': [
        \   options.patch ? 'patch' : '',
        \   options.ancestors ? 'ancestors' : '',
        \   options.ours ? 'ours' : '',
        \   options.theirs ? 'theirs' : '',
        \ ],
        \ 'commitish': commit,
        \ 'path': filename,
        \})
endfunction

function! s:on_BufReadCmd(options) abort
  call gita#util#doautocmd('BufReadPre')
  let options = gita#option#cascade('^show$', a:options, {
        \ 'patch': 0,
        \ 'ancestors': 0,
        \ 'ours': 0,
        \ 'theirs': 0,
        \ 'selection': [],
        \})
  let git = gita#core#get_or_fail()
  if options.patch || options.ancestors || options.ours || options.theirs
    " - INDEX content, naemly 'commit' should be an empty value
    " - file content, namely 'filename' is reqiured
    let options.commit = ''
    let options.filename = gita#variable#get_valid_filename(git, 
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
  call gita#util#buffer#edit_content(
        \ result.content,
        \ gita#autocmd#parse_cmdarg(),
        \)
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
  call gita#util#select(options.selection)
  call gita#util#doautocmd('BufReadPost')
endfunction

function! s:on_FileReadCmd(options) abort
  call gita#util#doautocmd('FileReadPre')
  let options = extend({
        \ 'encoding': '',
        \ 'fileformat': '',
        \ 'bad': '',
        \}, a:options)
  let options['quiet'] = 1
  let result = gita#command#show#call(options)
  call gita#util#buffer#read_content(
        \ result.content,
        \ gita#autocmd#parse_cmdarg(),
        \)
  call gita#util#doautocmd('FileReadPost')
endfunction

function! s:on_BufWriteCmd(options) abort
  call gita#util#doautocmd('BufWritePre')
  " This autocmd is executed ONLY when the buffer is shown as PATCH mode
  let tempfile = tempname()
  try
    let git = gita#core#get_or_fail()
    let filename = gita#meta#get_for('show', 'filename', '')
    let content  = s:get_diff_content(git, getline(1, '$'), filename)
    call writefile(content, tempfile)
    call gita#command#apply#call({
          \ 'quiet': 1,
          \ 'filenames': [tempfile],
          \ 'cached': 1,
          \})
    setlocal nomodified
    diffupdate
    call gita#util#doautocmd('BufWritePost')
  catch /^\%(vital: Git[:.]\|vim-gita:\)/
    call gita#util#handle_exception()
  finally
    call delete(tempfile)
  endtry
endfunction

function! s:on_FileWriteCmd(options) abort
  try
    call gita#throw('Writing a partial content is perhibited')
  catch /^\%(vital: Git[:.]\|vim-gita:\)/
    call gita#util#handle_exception()
  endtry
endfunction


function! gita#ui#show#autocmd(name) abort
  let git = gita#core#get_or_fail()
  let bufname = expand('<afile>')
  let m = matchlist(bufname, '^gita://[^:\\/]\+\%(:show\)\?:\([^\\/]\+\)[\\/]\(.*\)$')
  if empty(m)
    call gita#throw(printf(
          \ 'A bufname %s does not have required components',
          \ bufname,
          \))
  endif
  let [extra, treeish] = m[1 : 2]
  let [commit, unixpath] = s:GitTerm.split_treeish(treeish, { '_allow_range': 1 })
  let options = gita#util#cascade#get('show')
  let options.commit = commit
  let options.filename = empty(unixpath) ? '' : s:Git.get_absolute_path(git, unixpath)
  for option_name in split(extra, ':')
    let options[option_name] = 1
  endfor
  call call('s:on_' . a:name, [options])
endfunction

function! gita#ui#show#open(...) abort
  let options = extend({
        \ 'anchor': 0,
        \ 'opener': '',
        \ 'window': '',
        \ 'selection': [],
        \}, get(a:000, 0, {}))
  let bufname = s:get_bufname(options)
  let opener = empty(options.opener)
        \ ? g:gita#ui#show#default_opener
        \ : options.opener
  if options.anchor && gita#util#anchor#is_available(opener)
    call gita#util#anchor#focus()
  endif
  if bufname =~# '^gita:'
    call gita#util#cascade#set('show', options)
    call gita#util#buffer#open(bufname, {
          \ 'opener': opener,
          \ 'window': options.window,
          \})
  else
    if !empty(options.selection)
      let opener = empty(opener) ? 'edit' : opener
      let opener = printf('%s +%d', opener, options.selection[0])
    endif
    call gita#util#buffer#open(bufname, {
          \ 'opener': opener,
          \ 'window': options.window,
          \})
  endif
endfunction


call gita#util#define_variables('ui#show', {
      \ 'default_opener': '',
      \})
