function! s:_vital_loaded(V) abort
  let s:Prelude = a:V.import('Prelude')
  let s:StringExt = a:V.import('Data.String.Extra')
  let s:Git = a:V.import('Git')
  if !exists('s:const')
    let s:const = {}
    let s:const.markers = {}
    let s:const.markers.ours = s:StringExt.escape_regex(repeat('<', 7))
    let s:const.markers.separator = s:StringExt.escape_regex(repeat('=', 7))
    let s:const.markers.theirs = s:StringExt.escape_regex(repeat('>', 7))
    let s:const.patterns = {}
    let s:const.patterns.ours = printf(
          \ '%s[^\n]\{-}\%%(\n\|$\)',
          \ s:const.markers.ours
          \)
    let s:const.patterns.separator = printf(
          \ '%s[^\n]\{-}\%%(\n\|$\)',
          \ s:const.markers.separator
          \)
    let s:const.patterns.theirs = printf(
          \ '%s[^\n]\{-}\%%(\n\|$\)',
          \ s:const.markers.theirs
          \)
    lockvar s:const
  endif
endfunction
function! s:_vital_depends() abort
  return ['Prelude', 'Data.String.Extra', 'Git']
endfunction

function! s:has_ours_marker(buflines) abort
  let buflines = s:Prelude.is_list(a:buflines)
        \ ? join(a:buflines, "\n")
        \ : a:buflines
  return !empty(matchstr(buflines, s:const.patterns.ours))
endfunction
function! s:has_theirs_marker(buflines) abort
  let buflines = s:Prelude.is_list(a:buflines)
        \ ? join(a:buflines, "\n")
        \ : a:buflines
  return !empty(matchstr(buflines, s:const.patterns.theirs))
endfunction
function! s:has_conflict_marker(buflines) abort
  let buflines = s:Prelude.is_list(a:buflines)
        \ ? join(a:buflines, "\n")
        \ : a:buflines
  let ours_or_theirs = printf('%s\|%s',
        \ s:const.patterns.ours,
        \ s:const.patterns.theirs,
        \)
  return !empty(matchstr(buflines, ours_or_theirs))
endfunction

function! s:strip_ours(buflines, ...) abort
  let buflines = s:Prelude.is_list(a:buflines)
        \ ? join(a:buflines, "\n")
        \ : a:buflines
  let region_pattern = printf('%s.\{-}%s',
        \ s:const.patterns.ours,
        \ s:const.patterns.separator,
        \)
  let buflines = substitute(buflines, region_pattern . '\n\?', '', 'g')
  let buflines = substitute(buflines, s:const.patterns.theirs . '\n\?', '', 'g')
  return get(a:000, 0, s:Prelude.is_list(a:buflines))
        \ ? split(buflines, '\r\?\n', 1)
        \ : buflines
endfunction
function! s:strip_theirs(buflines, ...) abort
  let buflines = s:Prelude.is_list(a:buflines)
        \ ? join(a:buflines, "\n")
        \ : a:buflines
  let region_pattern = printf('%s.\{-}%s',
        \ s:const.patterns.separator,
        \ s:const.patterns.theirs,
        \)
  let buflines = substitute(buflines, region_pattern . '\n\?', '', 'g')
  let buflines = substitute(buflines, s:const.patterns.ours . '\n\?', '', 'g')
  return get(a:000, 0, s:Prelude.is_list(a:buflines))
        \ ? split(buflines, '\r\?\n', 1)
        \ : buflines
endfunction
function! s:strip_conflict(buflines, ...) abort
  let buflines = s:Prelude.is_list(a:buflines)
        \ ? join(a:buflines, "\n")
        \ : a:buflines
  let region_pattern = printf('%s.\{-}%s',
        \ s:const.patterns.ours,
        \ s:const.patterns.theirs,
        \)
  let buflines = substitute(buflines, region_pattern . '\n\?', '', 'g')
  return get(a:000, 0, s:Prelude.is_list(a:buflines))
        \ ? split(buflines, '\r\?\n', 1)
        \ : buflines
endfunction

function! s:get_ours(filename, ...) abort
  let options = extend({
        \ 'from_index': 1,
        \}, get(a:000, 0, {}))
  if options.from_index
    let result = s:Git.system(['show', ':2:' . a:filename])
    if result.status == 0
      return split(result.stdout, '\r\?\n', 1)
    endif
    return result
  else
    return s:strip_theirs(readfile(a:filename), 1)
  endif
endfunction
function! s:get_theirs(filename, ...) abort
  let options = extend({
        \ 'from_index': 1,
        \}, get(a:000, 0, {}))
  if options.from_index
    let result = s:Git.system(['show', ':3:' . a:filename])
    if result.status == 0
      return split(result.stdout, '\r\?\n', 1)
    endif
    return result
  else
    return s:strip_ours(readfile(a:filename), 1)
  endif
endfunction
function! s:get_base(filename, ...) abort
  let options = extend({
        \ 'from_index': 1,
        \}, get(a:000, 0, {}))
  if options.from_index
    let result = s:Git.system(['show', ':1:' . a:filename])
    if result.status == 0
      return split(result.stdout, '\r\?\n', 1)
    endif
    return result
  else
    return s:strip_conflict(readfile(a:filename), 1)
  endif
endfunction
