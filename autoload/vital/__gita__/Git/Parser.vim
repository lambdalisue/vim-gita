let s:root = expand('<sfile>:p:h')

function! s:_vital_loaded(V) abort
  let s:Prelude = a:V.import('Prelude')
  let s:String = a:V.import('Data.String')
  let s:Path = a:V.import('System.Filepath')
  let s:Python = a:V.import('Vim.Python')
  let s:STATUS = {}
  let s:STATUS.patterns = {}
  let s:STATUS.patterns.status = [
        \ '\v^([ MDARCUT\?!])([ MDUAT\?!])\s("[^"]+"|[^ ]+)%(\s-\>\s("[^"]+"|[^ ]+)|)$',
        \ '\v^([ MDARCUT\?!])([ MDUAT\?!])\s("[^"]+"|.+)$',
        \]
  let s:STATUS.patterns.header = [
        \ '\v^##\s([^.]+)\.\.\.([^ ]+).*$',
        \ '\v^##\s([^ ]+).*$',
        \]
  let s:STATUS.patterns.conflicted = '\v^%(DD|AU|UD|UA|DU|AA|UU)$'
  let s:STATUS.patterns.staged     = '\v^%([MARC][ MD]|D[ M]|T )$'
  let s:STATUS.patterns.unstaged   = '\v^%([ MARC][MD]|DM| T)$'
  let s:STATUS.patterns.untracked  = '\v^\?\?$'
  let s:STATUS.patterns.ignored    = '\v^!!$'
  let s:CONFLICT = {}
  let s:CONFLICT.markers = {}
  let s:CONFLICT.markers.ours = repeat('<', 7)
  let s:CONFLICT.markers.separator = repeat('=', 7)
  let s:CONFLICT.markers.theirs = repeat('>', 7)
  let s:CONFLICT.patterns = {}
  let s:CONFLICT.patterns.ours = printf(
        \ '%s[^\n]\{-}\%%(\n\|$\)',
        \ s:CONFLICT.markers.ours
        \)
  let s:CONFLICT.patterns.separator = printf(
        \ '%s[^\n]\{-}\%%(\n\|$\)',
        \ s:CONFLICT.markers.separator
        \)
  let s:CONFLICT.patterns.theirs = printf(
        \ '%s[^\n]\{-}\%%(\n\|$\)',
        \ s:CONFLICT.markers.theirs
        \)
endfunction

function! s:_vital_depends() abort
  return [
        \ 'Prelude',
        \ 'Data.String',
        \ 'System.Filepath',
        \ 'Vim.Python',
        \]
endfunction

function! s:_throw(msg) abort
  throw 'vital: Git.Parser: ' . a:msg
endfunction

" *** BlameParser ************************************************************
function! s:parse_blame(content, ...) abort
  let options = extend({
        \ 'progressbar': {},
        \ 'python': s:Python.is_enabled(),
        \}, get(a:000, 0, {}))
  let content = s:Prelude.is_string(a:content)
        \ ? split(a:content, '\r\?\n', 1)
        \ : a:content
  if options.python > 0 && !has('nvim')
    " NOTE:
    " neovim does not support 'vim.bindeval' yet so do not use Python
    " implementation in neovim
    return s:_parse_blame_python(content, options)
  else
    return s:_parse_blame_vim(content, options)
  endif
endfunction
" @vimlint(EVL102, 1, l:progressbar)
" @vimlint(EVL102, 1, l:kwargs)
function! s:_parse_blame_python(content, ...) abort
  let options = extend({
        \ 'progressbar': {},
        \ 'python': 1,
        \}, get(a:000, 0, {}))
  let python = options.python == 1 ? 0 : options.python
  let progressbar = options.progressbar
  let kwargs = {
        \ 'content': a:content,
        \}
  execute s:Python.exec_file(s:Path.join(s:root, 'Parser.py'), python)
  " NOTE:
  " To support neovim, bindeval cannot be used for now.
  " That's why eval_expr is required to call separatly
  let prefix = '_vim_vital_Git_Parser'
  let response = s:Python.eval_expr(prefix . '_response', python)
  let code = [
        \ printf('del %s_main', prefix),
        \ printf('del %s_response', prefix),
        \]
  execute s:Python.exec_code(code, python)
  if has_key(response, 'exception')
    call s:_throw(response.exception)
  endif
  return response.blameobj
endfunction
" @vimlint(EVL102, 0, l:progressbar)
" @vimlint(EVL102, 0, l:kwargs)
function! s:_parse_blame_vim(content, ...) abort
  let options = extend({
        \ 'progressbar': {},
        \}, get(a:000, 0, {}))
  let progressbar = options.progressbar
  let revisions = {}
  let chunks = []
  let current_revision = {}
  let current_chunk = {}
  let has_content = 0
  let chunk_index = -1
  for line in a:content
    if !empty(progressbar)
      call progressbar.update()
    endif
    let bits = split(line, '\W', 1)
    if len(bits[0]) == 40
      if len(bits) < 4
        " nlines column does not exists, mean that this line is in a current chunk
        continue
      endif
      let revision = bits[0]
      let headline = {
            \ 'revision':   revision,
            \ 'linenum': {
            \   'original': bits[1] + 0,
            \   'final':    bits[2] + 0,
            \ },
            \ 'nlines':     get(bits, 3, 0) + 0,
            \}
      if !has_key(revisions, revision)
        let revisions[revision] = {}
      endif
      let current_revision = revisions[revision]
      let chunk_index += 1
      let current_chunk = headline
      let current_chunk.index = chunk_index
      let current_chunk.contents = []
      call add(chunks, current_chunk)
      continue
    elseif len(bits[0]) == 0
      let has_content = 1
      "call add(current_chunk.contents, substitute(line, '^\t', '', ''))
      call add(current_chunk.contents, line[1:])
      continue
    elseif line ==# 'boundary'
      "call extend(current_revision, { 'boundary': 1 })
      let current_revision.boundary = 1
      continue
    else
      let bits = split(line, ' ', 1)
      let key = substitute(bits[0], '-', '_', 'g')
      let val = join(bits[1:], ' ')
      "call extend(current_revision, { key : val })
      let current_revision[key] = val
      continue
    endif
  endfor
  " Sort chunks with linenum.final and re-assign chunk index if no content
  " was detected
  if !has_content
    let chunks = sort(chunks, function('s:_compare_chunks'))
    let index = 0
    for chunk in chunks
      silent! unlet! chunk.content
      let chunk.index = index
      let index += 1
    endfor
  endif
  return {
        \ 'revisions': revisions,
        \ 'chunks': chunks,
        \ 'has_content': has_content,
        \}
endfunction

function! s:_compare_chunks(lhs, rhs) abort
  return a:lhs.linenum.final - a:rhs.linenum.final
endfunction


" *** StatusParser ***********************************************************
function! s:_extend_status(status) abort
  let sign = a:status.sign
  return extend(a:status, {
        \ 'is_conflicted': sign =~# s:STATUS.patterns.conflicted,
        \ 'is_staged':     sign =~# s:STATUS.patterns.staged,
        \ 'is_unstaged':   sign =~# s:STATUS.patterns.unstaged,
        \ 'is_untracked':  sign =~# s:STATUS.patterns.untracked,
        \ 'is_ignored':    sign =~# s:STATUS.patterns.ignored,
        \})
endfunction

function! s:_subtract_path(path) abort
  if a:path =~# '^".*"$'
    let path = substitute(a:path, '^"\|"$', '', 'g')
  elseif a:path =~# "^'.*'$"
    let path = substitute(a:path, "^'\|'$", '', 'g')
  else
    let path = a:path
  endif
  return path
endfunction

function! s:parse_status_record(line, ...) abort
  let options = extend({
        \ 'fail_silently': 0,
        \}, get(a:000, 0, {}))
  for pattern in s:STATUS.patterns.status
    let m = matchlist(a:line, pattern)
    let status = {}
    if len(m) > 5 && m[4] !=# ''
      " XY PATH1 -> PATH2 pattern
      let status = {
            \ 'index': m[1],
            \ 'worktree': m[2],
            \ 'path': s:_subtract_path(m[3]),
            \ 'path2': s:_subtract_path(m[4]),
            \ 'record': a:line,
            \ 'sign': m[1] . m[2],
            \}
      return s:_extend_status(status)
    elseif len(m) > 4 && m[3] !=# ''
      " XY PATH pattern
      let status = {
            \ 'index': m[1],
            \ 'worktree': m[2],
            \ 'path': s:_subtract_path(m[3]),
            \ 'record': a:line,
            \ 'sign': m[1] . m[2],
            \}
      return s:_extend_status(status)
    endif
  endfor
  for pattern in s:STATUS.patterns.header
    let m = matchlist(a:line, pattern)
    if len(m) > 2 && m[1] !=# ''
      return {
            \ 'current_branch': m[1],
            \ 'remote_branch': m[2],
            \}
    elseif len(m) > 1 && m[0] !=# ''
      return {
            \ 'current_branch': m[1],
            \ 'remote_branch': '',
            \}
    endif
  endfor
  if options.fail_silently
    return {}
  endif
  call s:_throw(printf('Parsing a status record "%s" has faield.', a:line))
endfunction

function! s:parse_status(content, ...) abort
  let options = extend({
        \ 'fail_silently': 0,
        \ 'flatten': 0,
        \}, get(a:000, 0, {}))
  let content = s:Prelude.is_string(a:content)
        \ ? split(a:content, '\r\?\n', 1)
        \ : a:content
  let result = {
        \ 'conflicted': [],
        \ 'staged': [],
        \ 'unstaged': [],
        \ 'untracked': [],
        \ 'ignored': [],
        \}
  for line in content
    let status = s:parse_status_record(line, options)
    if empty(status)
      continue
    elseif has_key(status, 'current_branch')
      call extend(result, status)
      continue
    elseif options.flatten
      call add(result.conflicted, status)
    else
      if status.is_conflicted
        call add(result.conflicted, status)
      endif
      if status.is_staged
        call add(result.staged, status)
      endif
      if status.is_unstaged
        call add(result.unstaged, status)
      endif
      if status.is_untracked
        call add(result.untracked, status)
      endif
      if status.is_ignored
        call add(result.is_ignored, status)
      endif
    endif
  endfor
  return options.flatten ? result.conflicted : result
endfunction

function! s:parse_numstat(content, ...) abort
  let content = s:Prelude.is_string(a:content)
        \ ? split(a:content, '\r\?\n', 1)
        \ : a:content
  let stats = []
  for line in content
    let m = matchlist(
          \ line,
          \ '^\(\d\+\)\s\+\(\d\+\)\s\+\(.\+\)$',
          \)
    if !empty(m)
      let [added, deleted, relpath] = m[1 : 3]
      call add(stats, {
            \ 'added':   str2nr(added),
            \ 'deleted': str2nr(deleted),
            \ 'path':    relpath,
            \})
    endif
  endfor
  return stats
endfunction

" *** ConflictParser *********************************************************
function! s:has_ours_marker(buflines) abort
  let buflines = s:Prelude.is_list(a:buflines)
        \ ? join(a:buflines, "\n")
        \ : a:buflines
  return !empty(matchstr(buflines, s:CONFLICT.patterns.ours))
endfunction

function! s:has_theirs_marker(buflines) abort
  let buflines = s:Prelude.is_list(a:buflines)
        \ ? join(a:buflines, "\n")
        \ : a:buflines
  return !empty(matchstr(buflines, s:CONFLICT.patterns.theirs))
endfunction

function! s:has_conflict_marker(buflines) abort
  let buflines = s:Prelude.is_list(a:buflines)
        \ ? join(a:buflines, "\n")
        \ : a:buflines
  let ours_or_theirs = printf('%s\|%s',
        \ s:CONFLICT.patterns.ours,
        \ s:CONFLICT.patterns.theirs,
        \)
  return !empty(matchstr(buflines, ours_or_theirs))
endfunction

function! s:strip_ours(buflines) abort
  let buflines = s:Prelude.is_list(a:buflines)
        \ ? join(a:buflines, "\n")
        \ : a:buflines
  let region_pattern = printf('%s.\{-}%s',
        \ s:CONFLICT.patterns.ours,
        \ s:CONFLICT.patterns.separator,
        \)
  let buflines = substitute(buflines, region_pattern . '\n\?', '', 'g')
  let buflines = substitute(buflines, s:CONFLICT.patterns.theirs . '\n\?', '', 'g')
  return get(a:000, 0, s:Prelude.is_list(a:buflines))
        \ ? split(buflines, '\r\?\n', 1)
        \ : buflines
endfunction

function! s:strip_theirs(buflines) abort
  let buflines = s:Prelude.is_list(a:buflines)
        \ ? join(a:buflines, "\n")
        \ : a:buflines
  let region_pattern = printf('%s.\{-}%s',
        \ s:CONFLICT.patterns.separator,
        \ s:CONFLICT.patterns.theirs,
        \)
  let buflines = substitute(buflines, region_pattern . '\n\?', '', 'g')
  let buflines = substitute(buflines, s:CONFLICT.patterns.ours . '\n\?', '', 'g')
  return get(a:000, 0, s:Prelude.is_list(a:buflines))
        \ ? split(buflines, '\r\?\n', 1)
        \ : buflines
endfunction

function! s:strip_conflict(buflines) abort
  let buflines = s:Prelude.is_list(a:buflines)
        \ ? join(a:buflines, "\n")
        \ : a:buflines
  let region_pattern = printf('%s.\{-}%s',
        \ s:CONFLICT.patterns.ours,
        \ s:CONFLICT.patterns.theirs,
        \)
  let buflines = substitute(buflines, region_pattern . '\n\?', '', 'g')
  return get(a:000, 0, s:Prelude.is_list(a:buflines))
        \ ? split(buflines, '\r\?\n', 1)
        \ : buflines
endfunction


" *** ConfigParser ***********************************************************
function! s:_make_nested_dict(keys, value) abort
  if len(a:keys) == 1
    return {a:keys[0]: a:value}
  else
    return {a:keys[0]: s:_make_nested_dict(a:keys[1:], a:value)}
  endif
endfunction

function! s:_extend_nested_dict(expr1, expr2) abort
  let expr1 = deepcopy(a:expr1)
  for [key, value] in items(a:expr2)
    if has_key(expr1, key)
      if type(value) == 4 && type(expr1[key]) == 4
        let expr1[key] = s:_extend_nested_dict(expr1[key], value)
      else
        let expr1[key] = value
      endif
    else
      let expr1[key] = value
    endif
  endfor
  return expr1
endfunction

function! s:parse_config_record(line) abort
  let m = matchlist(a:line, '\v^([^\=]+)\=(.*)$')
  if len(m) < 3
    call s:_throw('Parsing a config record failed: ' . a:line)
  endif
  " create a nested object
  let keys = split(m[1], '\.')
  let value = m[2]
  return s:_make_nested_dict(keys, value)
endfunction

function! s:parse_config(config) abort
  let obj = {}
  for line in split(a:config, '\r\?\n+')
    let obj = s:_extend_nested_dict(obj, s:parse_config_record(line))
  endfor
  return obj
endfunction


" *** BranchParser ***********************************************************
function! s:parse_branch_record(line) abort
  let candidate = {}
  let candidate.is_remote   = a:line =~# '^..remotes/'
  let candidate.is_selected = a:line =~# '^\*'
  let candidate.name = candidate.is_remote
        \ ? matchstr(a:line, '^..remotes/\zs[^ ]\+')
        \ : matchstr(a:line, '^..\zs[^ ]\+')
  let candidate.remote = candidate.is_remote
        \ ? matchstr(a:line, '^..remotes/\zs[^/]\+')
        \ : ''
  let candidate.linkto = candidate.is_remote
        \ ? matchstr(a:line, '^..remotes/[^ ]\+ -> \zs[^ ]\+')
        \ : ''
  let candidate.record = a:line
  return candidate
endfunction

function! s:parse_branch(content) abort
  let content = s:Prelude.is_string(a:content)
        \ ? split(a:content, '\r\?\n', 1)
        \ : a:content
  let branches = []
  for line in content
    if empty(line)
      continue
    endif
    call add(branches, s:parse_branch_record(line))
  endfor
  return branches
endfunction


" *** GrepParser *************************************************************
function! s:parse_match_record(line, ...) abort
  let options = extend({
        \ 'fail_silently': 0,
        \}, get(a:000, 0, {}))
  if a:line =~# '^[^:]\+:.\+:\d\+:.*$'
    " e.g. HEAD:README.md:5:foobar
    let m = matchlist(
          \ a:line,
          \ '^\([^:]\+\):\(.\+\):\(\d\+\):\(.*\)$',
          \)
    return {
          \ 'record': a:line,
          \ 'commit': m[1],
          \ 'path': m[2],
          \ 'selection': [str2nr(m[3])],
          \ 'content': m[4],
          \}
  elseif a:line =~# '^.\+:\d\+:.*$'
    " e.g. README.md:5:foobar
    let m = matchlist(
          \ a:line,
          \ '^\(.\+\):\(\d\+\):\(.*\)$',
          \)
    return {
          \ 'record': a:line,
          \ 'commit': '',
          \ 'path': m[1],
          \ 'selection': [str2nr(m[2])],
          \ 'content': m[3],
          \}
  endif
  if options.fail_silently
    return {}
  endif
  call s:_throw(printf('Parsing a match record "%s" has faield.', a:line))
endfunction

function! s:parse_match(content, ...) abort
  let options = get(a:000, 0, {
        \ 'line_length_threshold': 1000,
        \})
  let content = s:Prelude.is_string(a:content)
        \ ? split(a:content, '\r\?\n', 1)
        \ : a:content
  let matches = []
  for line in content
    if empty(line) || len(line) > options.line_length_threshold
      continue
    endif
    let match = s:parse_match_record(line, options)
    if !empty(match)
      call add(matches, match)
    endif
  endfor
  return matches
endfunction
