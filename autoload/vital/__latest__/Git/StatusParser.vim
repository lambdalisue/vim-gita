function! s:_vital_loaded(V) abort
  let s:Prelude = a:V.import('Prelude')
endfunction
function! s:_vital_depends() abort
  return ['Prelude']
endfunction
function! s:_vital_created(module) abort
  if !exists('s:const')
    " NOTE:
    " Support 'T' as well
    let s:const = {}
    let s:const.patterns = {}
    let s:const.patterns.status = [
          \ '\v^([ MDARCU\?!])([ MDUA\?!])\s("[^"]+"|[^ ]+)%(\s-\>\s("[^"]+"|[^ ]+)|)$',
          \ '\v^([ MDARCU\?!])([ MDUA\?!])\s("[^"]+"|.+)$',
          \]
    let s:const.patterns.header = [
          \ '\v^##\s([^.]+)\.\.\.([^ ]+).*$',
          \ '\v^##\s([^ ]+).*$',
          \]
    let s:const.patterns.conflicted = '\v^%(DD|AU|UD|UA|DU|AA|UU)$'
    let s:const.patterns.staged     = '\v^%([MARC][ MD]|D[ M])$'
    let s:const.patterns.unstaged   = '\v^%([ MARC][MD]|DM)$'
    let s:const.patterns.untracked  = '\v^\?\?$'
    let s:const.patterns.ignored    = '\v^!!$'
    lockvar s:const
  endif
  call extend(a:module, s:const)
endfunction

function! s:_throw(msg) abort
  throw 'vital: Git.StatusParser: ' . a:msg
endfunction

function! s:_extend_status(status) abort
  let sign = a:status.sign
  return extend(a:status, {
        \ 'is_conflicted': sign =~# s:const.patterns.conflicted,
        \ 'is_staged':     sign =~# s:const.patterns.staged,
        \ 'is_unstaged':   sign =~# s:const.patterns.unstaged,
        \ 'is_untracked':  sign =~# s:const.patterns.untracked,
        \ 'is_ignored':    sign =~# s:const.patterns.ignored,
        \})
endfunction
function! s:_ensure_path(path) abort
  if a:path =~# '^".*"$'
    let path = substitute(a:path, '^"\|"$', '', 'g')
  elseif a:path =~# "^'.*'$"
    let path = substitute(a:path, "^'\|'$", '', 'g')
  else
    let path = a:path
  endif
  return path
endfunction

function! s:parse_record(line, ...) abort
  let options = extend({
        \ 'fail_silently': 0,
        \}, get(a:000, 0, {}))
  for pattern in s:const.patterns.status
    let m = matchlist(a:line, pattern)
    let status = {}
    if len(m) > 5 && m[4] !=# ''
      " XY PATH1 -> PATH2 pattern
      let status = {
            \ 'index': m[1],
            \ 'worktree': m[2],
            \ 'path': s:_ensure_path(m[3]),
            \ 'path2': s:_ensure_path(m[4]),
            \ 'record': a:line,
            \ 'sign': m[1] . m[2],
            \}
      return s:_extend_status(status)
    elseif len(m) > 4 && m[3] !=# ''
      " XY PATH pattern
      let status = {
            \ 'index': m[1],
            \ 'worktree': m[2],
            \ 'path': s:_ensure_path(m[3]),
            \ 'record': a:line,
            \ 'sign': m[1] . m[2],
            \}
      return s:_extend_status(status)
    endif
  endfor
  for pattern in s:const.patterns.header
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
  call s:_throw(printf('Parsing a record "%s" has faield.', a:line))
endfunction
function! s:parse(content, ...) abort
  let options = extend({
        \ 'fail_silently': 0,
        \ 'flatten': 1,
        \}, get(a:000, 0, {}))
  let content = s:Prelude.is_string(a:content)
        \ ? split(a:content, '\r\?\n', 1)
        \ : a:content
  let result = { 'statuses': [] }
  for line in content
    let status = s:parse_record(line, options)
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
