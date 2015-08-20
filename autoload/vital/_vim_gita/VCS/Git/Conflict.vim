"******************************************************************************
" A parser for Git conflict markers
"
" Author:   Alisue <lambdalisue@hashnote.net>
" URL:      http://hashnote.net/
" License:  MIT license
" (C) 2015, Alisue, hashnote.net
"******************************************************************************
let s:save_cpo = &cpo
set cpo&vim

function! s:_vital_loaded(V) abort " {{{
  let s:P = a:V.import('Prelude')
  let s:C = a:V.import('VCS.Git.Core')
endfunction " }}}
function! s:_vital_created(module) abort " {{{
  let s:const = {}
  let s:const.markers = {}
  let s:const.markers.ours  = repeat('\<', 7)
  let s:const.markers.separator   = repeat('\=', 7)
  let s:const.markers.theirs = repeat('\>', 7)
  let s:const.patterns = {}
  let s:const.patterns.ours = printf('%s[^\n]{-}%%(\n|$)', s:const.markers.ours)
  let s:const.patterns.separator = printf('%s[^\n]{-}%%(\n|$)', s:const.markers.separator)
  let s:const.patterns.theirs = printf('%s[^\n]{-}%%(\n|$)', s:const.markers.theirs)
  lockvar s:const
  call extend(a:module, s:const)
endfunction " }}}
function! s:_vital_depends() abort " {{{
  return [
        \ 'Prelude',
        \ 'VCS.Git.Core',
        \]
endfunction " }}}

function! s:has_ours_marker(buflines) abort " {{{
  let buflines = s:P.is_list(a:buflines) ? join(a:buflines, "\n") : a:buflines
  return !empty(matchstr(buflines, '\v' . s:const.patterns.ours))
endfunction " }}}
function! s:has_theirs_marker(buflines) abort " {{{
  let buflines = s:P.is_list(a:buflines) ? join(a:buflines, "\n") : a:buflines
  return !empty(matchstr(buflines, '\v' . s:const.patterns.theirs))
endfunction " }}}
function! s:has_conflict_marker(buflines) abort " {{{
  let buflines = s:P.is_list(a:buflines) ? join(a:buflines, "\n") : a:buflines
  let ours_or_theirs = printf('%%(%s|%s)',
        \ s:const.patterns.ours,
        \ s:const.patterns.theirs,
        \)
  return !empty(matchstr(buflines, '\v' . ours_or_theirs))
endfunction " }}}

function! s:strip_ours(buflines, ...) abort " {{{
  let buflines = s:P.is_list(a:buflines) ? join(a:buflines, "\n") : a:buflines
  let region_pattern = printf('%s.{-}%s',
        \ s:const.patterns.ours,
        \ s:const.patterns.separator,
        \)
  let buflines = substitute(buflines, '\v' . region_pattern . '\n?', '', 'g')
  let buflines = substitute(buflines, '\v' . s:const.patterns.theirs . '\n?', '', 'g')
  return get(a:000, 0, s:P.is_list(a:buflines)) ? split(buflines, '\v\r?\n') : buflines
endfunction " }}}
function! s:strip_theirs(buflines, ...) abort " {{{
  let buflines = s:P.is_list(a:buflines) ? join(a:buflines, "\n") : a:buflines
  let region_pattern = printf('%s.{-}%s',
        \ s:const.patterns.separator,
        \ s:const.patterns.theirs,
        \)
  let buflines = substitute(buflines, '\v' . region_pattern . '\n?', '', 'g')
  let buflines = substitute(buflines, '\v' . s:const.patterns.ours . '\n?', '', 'g')
  return get(a:000, 0, s:P.is_list(a:buflines)) ? split(buflines, '\v\r?\n') : buflines
endfunction " }}}
function! s:strip_conflict(buflines, ...) abort " {{{
  let buflines = s:P.is_list(a:buflines) ? join(a:buflines, "\n") : a:buflines
  let region_pattern = printf('%s.{-}%s',
        \ s:const.patterns.ours,
        \ s:const.patterns.theirs,
        \)
  let buflines = substitute(buflines, '\v' . region_pattern . '\n?', '', 'g')
  return get(a:000, 0, s:P.is_list(a:buflines)) ? split(buflines, '\v\r?\n') : buflines
endfunction " }}}

function! s:get_ours(filename, ...) abort " {{{
  let opts = extend({
        \ 'from_index': 1,
        \}, get(a:000, 0, {}))
  if opts.from_index
    let result = s:C.exec(['show', ':2:' . a:filename], opts)
    if result.status == 0
      return split(result.stdout, '\v\r?\n')
    endif
    return result
  else
    return s:strip_theirs(readfile(a:filename), 1)
  endif
endfunction " }}}
function! s:get_theirs(filename, ...) abort " {{{
  let opts = extend({
        \ 'from_index': 1,
        \}, get(a:000, 0, {}))
  if opts.from_index
    let result = s:C.exec(['show', ':3:' . a:filename], opts)
    if result.status == 0
      return split(result.stdout, '\v\r?\n')
    endif
    return result
  else
    return s:strip_ours(readfile(a:filename), 1)
  endif
endfunction " }}}
function! s:get_base(filename, ...) abort " {{{
  let opts = extend({
        \ 'from_index': 1,
        \}, get(a:000, 0, {}))
  if opts.from_index
    let result = s:C.exec(['show', ':1:' . a:filename], opts)
    if result.status == 0
      return split(result.stdout, '\v\r?\n')
    endif
    return result
  else
    return s:strip_conflict(readfile(a:filename), 1)
  endif
endfunction " }}}


let &cpo = s:save_cpo
unlet s:save_cpo
"vim: sts=2 sw=2 smarttabb et ai textwidth=0 fdm=marker

