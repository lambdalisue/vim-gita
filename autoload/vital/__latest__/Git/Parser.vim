function! s:_vital_loaded(V) abort
  let s:Prelude = a:V.import('Prelude')
  let s:StringExt = a:V.import('Data.StringExt')
  " NOTE:
  " Support 'T' as well
  let s:STATUS = {}
  let s:STATUS.patterns = {}
  let s:STATUS.patterns.status = [
        \ '\v^([ MDARCU\?!])([ MDUA\?!])\s("[^"]+"|[^ ]+)%(\s-\>\s("[^"]+"|[^ ]+)|)$',
        \ '\v^([ MDARCU\?!])([ MDUA\?!])\s("[^"]+"|.+)$',
        \]
  let s:STATUS.patterns.header = [
        \ '\v^##\s([^.]+)\.\.\.([^ ]+).*$',
        \ '\v^##\s([^ ]+).*$',
        \]
  let s:STATUS.patterns.conflicted = '\v^%(DD|AU|UD|UA|DU|AA|UU)$'
  let s:STATUS.patterns.staged     = '\v^%([MARC][ MD]|D[ M])$'
  let s:STATUS.patterns.unstaged   = '\v^%([ MARC][MD]|DM)$'
  let s:STATUS.patterns.untracked  = '\v^\?\?$'
  let s:STATUS.patterns.ignored    = '\v^!!$'
  let s:CONFLICT = {}
  let s:CONFLICT.markers = {}
  let s:CONFLICT.markers.ours = s:StringExt.escape_regex(repeat('<', 7))
  let s:CONFLICT.markers.separator = s:StringExt.escape_regex(repeat('=', 7))
  let s:CONFLICT.markers.theirs = s:StringExt.escape_regex(repeat('>', 7))
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
        \ 'Data.StringExt',
        \]
endfunction

function! s:_throw(msg) abort
  throw 'vital: Git.Parser: ' . a:msg
endfunction

" *** BlameParser ************************************************************
function! s:parse_blame(blame, ...) abort
  let Callback = get(a:000, 0, 0)
  let is_callable = s:Prelude.is_funcref(Callback)
  let revisions = {}
  let lineinfos = []
  let current_revision = {}
  let current_lineinfo = {}
  let lines = s:Prelude.is_string(a:blame)
        \ ? split(a:blame, '\r\?\n', 1)
        \ : a:blame
  for line in lines
    let bits = split(line, '\W', 1)
    if len(bits[0]) == 40
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
      if !empty(current_lineinfo) && is_callable
        call call(Callback, [revisions, current_lineinfo])
      endif
      let current_revision = revisions[revision]
      let current_lineinfo = headline
      call add(lineinfos, current_lineinfo)
      continue
    elseif len(bits[0]) == 0
      call extend(current_lineinfo, { 'contents': substitute(line, '^\t', '', '') })
      continue
    elseif line ==# 'boundary'
      call extend(current_revision, { 'boundary': 1 })
      continue
    else
      let bits = split(line, ' ', 1)
      let key = substitute(bits[0], '-', '_', 'g')
      let val = join(bits[1:], ' ')
      call extend(current_revision, { key : val })
      continue
    endif
  endfor
  return {
        \ 'revisions': revisions,
        \ 'lineinfos': lineinfos,
        \}
endfunction

function! s:parse_blame_to_chunks(blame, ...) abort
  let Callback = get(a:000, 0, 0)
  let is_callable = s:Prelude.is_funcref(Callback)
  let revisions = {}
  let chunks = []
  let current_revision = {}
  let current_chunk = {}
  let chunk_index = -1
  let lines = s:Prelude.is_string(a:blame)
        \ ? split(a:blame, '\r\?\n', 1)
        \ : a:blame
  for line in lines
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
      if chunk_index > -1 && is_callable
        call call(Callback, [revisions, current_chunk])
      endif
      let chunk_index += 1
      let current_chunk = headline
      let current_chunk.index = chunk_index
      let current_chunk.contents = []
      call add(chunks, current_chunk)
      continue
    elseif len(bits[0]) == 0
      call add(current_chunk.contents, substitute(line, '^\t', '', ''))
      continue
    elseif line ==# 'boundary'
      call extend(current_revision, { 'boundary': 1 })
      continue
    else
      let bits = split(line, ' ', 1)
      let key = substitute(bits[0], '-', '_', 'g')
      let val = join(bits[1:], ' ')
      call extend(current_revision, { key : val })
      continue
    endif
  endfor
    if chunk_index > -1 && is_callable
      call call(Callback, [revisions, current_chunk])
    endif
  return {
        \ 'revisions': revisions,
        \ 'chunks': chunks,
        \}
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
        \ 'flatten': 1,
        \}, get(a:000, 0, {}))
  let content = s:Prelude.is_string(a:content)
        \ ? split(a:content, '\r\?\n', 1)
        \ : a:content
  let result = { 'statuses': [] }
  for line in content
    let status = s:parse_status_record(line, options)
    if empty(status)
      continue
    elseif has_key(status, 'current_branch')
      call extend(result, status)
      continue
    else
      call add(result.statuses, status)
    endif
  endfor
  return options.flatten ? result.statuses : result
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