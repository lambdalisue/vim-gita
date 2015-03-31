"******************************************************************************
" Git repository finder which use file based cache system to improve response
"
" Author:   Alisue <lambdalisue@hashnote.net>
" URL:      http://hashnote.net/
" License:  MIT license
" (C) 2014, Alisue, hashnote.net
"******************************************************************************
let s:save_cpo = &cpo
set cpo&vim

function! s:_vital_loaded(V) dict abort " {{{
  let s:V = a:V
  let s:Prelude = a:V.import('Prelude')
  let s:Path    = a:V.import('System.Filepath')
  let s:Core    = a:V.import('VCS.Git.Core')
endfunction " }}}
function! s:_vital_depends() abort " {{{
  return [
        \ 'Prelude',
        \ 'System.Filepath',
        \ 'VCS.Git.Core',
        \]
endfunction " }}}

let s:finder = {}
function! s:finder.find(path, ...) abort " {{{
  let options = extend({ 'no_cache': 0 }, get(a:000, 0, {}))
  let abspath = s:Prelude.path2directory(fnamemodify(a:path, ':p'))
  let metainfo = self.cache.get(abspath, {})
  if !empty(metainfo) && metainfo.path == abspath && !options.no_cache
    if strlen(metainfo.worktree)
      return { 'worktree': metainfo.worktree, 'repository': metainfo.repository }
    else
      return {}
    endif
  endif

  let worktree = s:Core.find_worktree(abspath)
  let repository = strlen(worktree) ? s:Core.find_repository(worktree) : ''
  let metainfo = {
        \ 'path': abspath,
        \ 'worktree': worktree,
        \ 'repository': repository,
        \}
  call self.cache.set(abspath, metainfo)
  if strlen(metainfo.worktree)
    return { 'worktree': metainfo.worktree, 'repository': metainfo.repository }
  else
    return {}
  endif
endfunction " }}}
function! s:finder.clear() abort " {{{
  call self.cache.clear()
endfunction " }}}
function! s:finder.gc() abort " {{{
  let opts = extend({
        \ 'verbose': 1,
        \}, get(a:000, 0, {}))
  let keys = self.cache.keys()
  let n = len(keys)
  let c = 1
  for key in keys
    let metainfo = self.cache.get(key)
    if isdirectory(metainfo.path)
      let metainfo.worktree = s:Core.find_worktree(metainfo.path)
      let metainfo.repository = s:Core.find_repository(metainfo.worktree)
      if opts.verbose
        redraw
        echomsg printf("%d/%d: '%s' is a %s",
              \ c, n, metainfo.path,
              \ strlen(metainfo.worktree) ? 'worktree' : 'not worktree',
              \)
      endif
      call self.cache.set(key, metainfo)
    else
      " missing path
      call self.cache.remove(key)
      if opts.verbose
        redraw
        echomsg printf("%d/%d: '%s' is missing",
              \ c, n, metainfo.path,
              \)
      endif
    endif
    let c += 1
  endfor
endfunction " }}}

function! s:new(cache) abort " {{{
  " validate cache instance
  let required_methods = ['get', 'set', 'keys', 'remove', 'clear']
  for method in required_methods
    if !has_key(a:cache, method)
      throw "VCS.Git.Finder: the cache instance does not have required method."
    endif
  endfor
  return extend(deepcopy(s:finder), { 'cache': a:cache })
endfunction " }}}

let &cpo = s:save_cpo
unlet s:save_cpo
"vim: sts=2 sw=2 smarttabb et ai textwidth=0 fdm=marker
