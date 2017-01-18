let s:V = gita#vital()
let s:Prelude = s:V.import('Prelude')
let s:String = s:V.import('Data.String')
let s:Path = s:V.import('System.Filepath')
let s:Console = s:V.import('Vim.Console')
let s:Git = s:V.import('Git')
let s:GitInfo = s:V.import('Git.Info')
let s:GitTerm = s:V.import('Git.Term')

function! s:replace_filenames_in_diff(content, filename1, filename2, repl, ...) abort
  let is_windows = get(a:000, 0, s:Prelude.is_windows())
  " replace tempfile1/tempfile2 in the header to a:filename
  "
  "   diff --git a/<tempfile1> b/<tempfile2>
  "   index XXXXXXX..XXXXXXX XXXXXX
  "   --- a/<tempfile1>
  "   +++ b/<tempfile2>
  "
  let src1 = s:String.escape_pattern(a:filename1)
  let src2 = s:String.escape_pattern(a:filename2)
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
  let filename = gita#normalize#relpath(a:git, a:filename)
  let tempfile = tempname()
  let tempfile1 = tempfile . '.index'
  let tempfile2 = tempfile . '.buffer'
  try
    " save contents to temporary files
    let git = gita#core#get_or_fail()
    try
      let content = gita#process#execute(
            \ git,
            \ ['show', ':' . filename],
            \ { 'quiet': 1, 'encode_output': 0 }
            \).content
    catch /vital: Git.Process: Fail/
      " NOTE:
      " the content of filename does not exist
      let content = []
    endtry
    call writefile(content, tempfile1)
    call writefile(a:content, tempfile2)
    " create a diff content between index_content and content
    " NOTE:
    " --no-index force --exit-code option.
    " --exit-code mean that the program exits with 1 if there were differences
    " and 0 means no differences
    let content = gita#process#execute(
          \ git,
          \ ['diff', '--no-index', '--unified=1', '--', tempfile1, tempfile2],
          \ { 'quiet': 1, 'encode_output': 0, 'fail_silently': 1 }
          \).content
    if empty(content) || len(content) < 4
      " fail or no differences. Assume that there are no differences
      call s:Console.debug(content)
      call gita#throw('Attention: No differences are detected')
    endif
    return s:replace_filenames_in_diff(
          \ content,
          \ tempfile1,
          \ tempfile2,
          \ filename,
          \)
  finally
    call delete(tempfile1)
    call delete(tempfile2)
  endtry
endfunction

function! s:build_bufname(options) abort
  let options = extend({
        \ 'commit': '',
        \ 'filename': '',
        \ 'silent': 0,
        \ 'patch': 0,
        \ 'worktree': 0,
        \ 'ancestors': 0,
        \ 'ours': 0,
        \ 'theirs': 0,
        \}, a:options)
  if options.worktree
    let git = gita#core#get()
    let filename = gita#normalize#abspath(git, options.filename)
    if !filereadable(filename)
      call gita#throw(printf(
            \ 'A filename "%s" could not be found in the working tree',
            \ filename,
            \))
    endif
    return filename
  else
    let git = gita#core#get_or_fail()
    if options.ancestors || options.ours || options.theirs
      let treeish = printf(':%d:%s',
            \ options.ancestors ? 1 : options.ours ? 2 : 3,
            \ gita#normalize#relpath(git, options.filename),
            \)
    else
      let treeish = printf('%s:%s',
            \ options.commit,
            \ gita#normalize#relpath(git, options.filename),
            \)
    endif
    return gita#content#build_bufname('show', {
          \ 'extra_options': [
          \   options.silent ? 'silent': '',
          \   options.patch ? 'patch' : '',
          \ ],
          \ 'treeish': treeish,
          \})
  endif
endfunction

function! s:parse_bufname(bufinfo) abort
  let m = matchlist(a:bufinfo.treeish, '^\(\%(:[0-3]\)\?[^:]*\)\%(:\(.*\)\)\?$')
  if empty(m)
    call gita#throw(printf(
          \ 'A treeish part of a buffer name "%s" does not follow "%s" pattern',
          \ a:bufinfo.bufname, '<rev>:<filename> or :<n>:<filename>',
          \))
  endif
  let a:bufinfo.ancestors = m[1] =~# '^:1'
  let a:bufinfo.ours = m[1] =~# '^:2'
  let a:bufinfo.theirs = m[1] =~# '^:3'
  let a:bufinfo.commit = substitute(m[1], '^:\d\+', '', '')
  let a:bufinfo.filename = m[2]
  return a:bufinfo
endfunction

function! s:args_from_options(git, options) abort
  let options = extend({
        \ 'ancestors': 0,
        \ 'ours': 0,
        \ 'theirs': 0,
        \ 'commit': '',
        \ 'filename': '',
        \}, a:options)
  if options.ancestors || options.ours || options.theirs
    let treeish = printf(':%d:%s',
          \ options.ancestors ? 1 : options.ours ? 2 : 3,
          \ gita#normalize#relpath(a:git, options.filename),
          \)
  else
    let treeish = printf('%s:%s',
          \ gita#normalize#commit(a:git, options.commit),
          \ gita#normalize#relpath(a:git, options.filename),
          \)
  endif
  let treeish = empty(options.filename)
        \ ? substitute(treeish, ':$', '', '')
        \ : treeish
  return filter(['show', treeish], '!empty(v:val)')
endfunction

function! s:execute_command(options) abort
  let git = gita#core#get_or_fail()
  let args = s:args_from_options(git, a:options)
  if get(a:options, 'silent')
    try
      return gita#process#execute(git, args, {
            \ 'quiet': 1,
            \ 'encode_output': 0,
            \}).content
    catch /vital: Git.Process: Fail/
      " NOTE:
      " diff-2/3, patch-2/3 may request content which does not exist so
      " return an empty content in that case
      return []
    endtry
  else
    return gita#process#execute(git, args, {
          \ 'quiet': 1,
          \ 'encode_output': 0,
          \}).content
  endif
endfunction

function! s:on_BufReadCmd(options) abort
  call gita#util#doautocmd('BufReadPre')
  let options = gita#util#option#cascade('^show$', a:options)
  let content = s:execute_command(options)
  call gita#meta#set('content_type', 'show')
  call gita#meta#set('options', options)
  call gita#meta#set('commit', options.commit)
  call gita#meta#set('filename', options.filename)
  call gita#util#buffer#edit_content(
        \ content,
        \ gita#util#buffer#parse_cmdarg(),
        \)
  if get(options, 'patch')
    setlocal buftype=acwrite
    setlocal noreadonly
  else
    if empty(options.filename)
      setfiletype git
    endif
    setlocal buftype=nowrite
    setlocal readonly
  endif
  call gita#util#doautocmd('BufReadPost')
endfunction

function! s:on_FileReadCmd(options) abort
  call gita#util#doautocmd('FileReadPre')
  let content = s:execute_command(a:options)
  call gita#util#buffer#read_content(
        \ content,
        \ gita#util#buffer#parse_cmdarg(),
        \)
  call gita#util#doautocmd('FileReadPost')
endfunction

function! s:on_BufWriteCmd(options) abort
  call gita#util#doautocmd('BufWritePre')
  " This autocmd is executed ONLY when the buffer is shown as PATCH mode
  let tempfile = tempname()
  try
    let git = gita#core#get_or_fail()
    let filename = gita#meta#get_for('^show$', 'filename', '')
    let content = s:get_diff_content(git, getline(1, '$'), filename)
    call writefile(content, tempfile)
    call gita#process#execute(
          \ git,
          \ ['apply', '--verbose', '--cached', '--', tempfile],
          \)
    setlocal nomodified
    call gita#trigger_modified()
    call gita#util#doautocmd('BufWritePost')
    diffupdate
  catch /^\%(vital: Git[:.]\|gita:\)/
    call gita#util#handle_exception()
  finally
    call delete(tempfile)
  endtry
endfunction

function! s:on_FileWriteCmd(options) abort
  call gita#throw('Writing a partial content is perhibited')
endfunction

function! gita#content#show#open(options) abort
  let options = extend({
        \ 'opener': '',
        \ 'window': '',
        \ 'selection': [],
        \}, a:options)
  let bufname = s:build_bufname(options)
  if bufname =~# '^gita:'
    call gita#util#cascade#set('show', options)
    call gita#util#buffer#open(bufname, {
          \ 'opener': options.opener,
          \ 'window': options.window,
          \ 'selection': options.selection,
          \})
  else
    call gita#util#buffer#open(bufname, {
          \ 'opener': options.opener,
          \ 'window': options.window,
          \ 'selection': options.selection,
          \})
  endif
endfunction

function! gita#content#show#autocmd(name, bufinfo) abort
  let bufinfo = s:parse_bufname(a:bufinfo)
  let options = gita#util#cascade#get('show')
  let options.ancestors = bufinfo.ancestors
  let options.ours = bufinfo.ours
  let options.theirs = bufinfo.theirs
  let options.commit = bufinfo.commit
  let options.filename = bufinfo.filename
  let options.treeish = bufinfo.treeish
  for attribute in bufinfo.extra_options
    let options[attribute] = 1
  endfor
  call call('s:on_' . a:name, [options])
endfunction

call gita#define_variables('content#show', {
      \ 'default_opener': 'edit',
      \})
