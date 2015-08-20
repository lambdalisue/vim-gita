"******************************************************************************
" A fundemental git manipulation library
"
" Author:   Alisue <lambdalisue@hashnote.net>
" URL:      http://hashnote.net/
" License:  MIT license
"
" (C) 2014, Alisue, hashnote.net
"******************************************************************************
let s:save_cpo = &cpo
set cpo&vim

" Vital ======================================================================
function! s:_vital_loaded(V) abort " {{{
  let s:Dict = a:V.import('Data.Dict')
  let s:List = a:V.import('Data.List')
  let s:Prelude = a:V.import('Prelude')
  let s:Path = a:V.import('System.Filepath')
  let s:Cache = a:V.import('System.Cache.Memory')
  let s:Core = a:V.import('VCS.Git.Core')
  let s:Finder = a:V.import('VCS.Git.Finder')
  let s:StatusParser = a:V.import('VCS.Git.StatusParser')
  let s:ConfigParser = a:V.import('VCS.Git.ConfigParser')

  let s:SEPARATOR = s:Path.separator()
endfunction " }}}
function! s:_vital_depends() abort " {{{
  return [
        \ 'Prelude',
        \ 'Data.Dict',
        \ 'Data.List',
        \ 'System.Filepath',
        \ 'System.Cache.Memory',
        \ 'VCS.Git.Core',
        \ 'VCS.Git.Finder',
        \ 'VCS.Git.StatusParser',
        \ 'VCS.Git.ConfigParser',
        \]
endfunction " }}}
function! s:_listalize(val) abort " {{{
  return s:Prelude.is_list(a:val) ? a:val : [a:val]
endfunction " }}}

function! s:_get_finder() abort " {{{
  if !exists('s:finder')
    let s:finder = s:Finder.new(s:_get_finder_cache())
  endif
  return s:finder
endfunction " }}}
function! s:_get_finder_cache() abort " {{{
  if !exists('s:finder_cache')
    let config = s:get_config()
    let s:finder_cache = call(
          \ config.cache.finder.new,
          \ config.cache.finder_args,
          \ config.cache.finder,
          \)
  endif
  return s:finder_cache
endfunction " }}}
function! s:_get_instance_cache() abort " {{{
  if !exists('s:instance_cache')
    let config = s:get_config()
    let s:instance_cache = call(
          \ config.cache.instance.new,
          \ config.cache.instance_args,
          \ config.cache.instance,
          \)
  endif
  return s:instance_cache
endfunction " }}}

let s:config = {}
function! s:get_config() abort " {{{
  let default = {
        \ 'cache': {
        \   'finder':   s:Cache,
        \   'instance': s:Cache,
        \   'repository': s:Cache,
        \   'uptime':   s:Cache,
        \   'finder_args': [],
        \   'instance_args': [],
        \   'repository_args': [],
        \   'uptime_args': [],
        \ },
        \}
  return extend(default, deepcopy(s:config))
endfunction " }}}
function! s:set_config(config) abort " {{{
  let s:config = extend(s:config, a:config)
  " clear settings
  unlet! s:finder_cache
  unlet! s:finder
  unlet! s:instance_cache
  " apply settings
  call s:Core.set_config(s:config)
endfunction " }}}
function! s:new(worktree, repository, ...) abort " {{{
  let opts = extend({ 'no_cache': 0 }, get(a:000, 0, {}))
  let cache = s:_get_instance_cache()
  let git = cache.get(a:worktree, {})
  if !empty(git) && !opts.no_cache
    return git
  endif
  let config = s:get_config()
  let git = extend(deepcopy(s:git), {
        \ 'worktree': a:worktree,
        \ 'repository': a:repository,
        \ 'cache': {
        \   'repository': call(
        \     config.cache.repository.new,
        \     config.cache.repository_args,
        \     config.cache.repository
        \   ),
        \   'uptime': call(
        \     config.cache.uptime.new,
        \     config.cache.uptime_args,
        \     config.cache.uptime
        \   ),
        \ }
        \})
  call cache.set(a:worktree, git)
  return git
endfunction " }}}
function! s:find(path, ...) abort " {{{
  let options = get(a:000, 0, {})
  let finder = s:_get_finder()
  let found = finder.find(a:path, options)
  if empty(found)
    return {}
  endif
  return s:new(found.worktree, found.repository, options)
endfunction " }}}

" Object =====================================================================
let s:git = {}
function! s:git.is_updated(pathspec, ...) abort " {{{
  let pathspec = s:_listalize(a:pathspec)
  let path = s:Path.join(pathspec)
  let name = printf('%s%s%s', path, s:SEPARATOR, get(a:000, 0, ''))
  let cached = self.cache.uptime.get(name, -1)
  let actual = getftime(s:Path.join(self.repository, path))
  call self.cache.uptime.set(name, actual)
  return actual == -1 || actual > cached
endfunction " }}}

" VCS.Git.Core
function! s:git.get_relative_path(path) abort " {{{
  return s:Core.get_relative_path(self.worktree, a:path)
endfunction " }}}
function! s:git.get_absolute_path(path) abort " {{{
  return s:Core.get_absolute_path(self.worktree, a:path)
endfunction " }}}

function! s:git.get_head(...) abort " {{{
  let options = extend({
        \ 'no_cache': 0,
        \}, get(a:000, 0, {}))
  let name = 'HEAD'
  let cache = self.cache.repository
  if self.is_updated(name) || options.no_cache || !cache.has(name)
    let result = s:Core.get_head(self.repository)
    call cache.set(name, result)
  endif
  return cache.get(name)
endfunction " }}}
function! s:git.get_fetch_head(...) abort " {{{
  let options = extend({
        \ 'no_cache': 0,
        \}, get(a:000, 0, {}))
  let name = 'FETCH_HEAD'
  let cache = self.cache.repository
  if self.is_updated(name) || options.no_cache || !cache.has(name)
    let result = s:Core.get_fetch_head(self.repository)
    call cache.set(name, result)
  endif
  return cache.get(name)
endfunction " }}}
function! s:git.get_orig_head(...) abort " {{{
  let options = extend({
        \ 'no_cache': 0,
        \}, get(a:000, 0, {}))
  let name = 'ORIG_HEAD'
  let cache = self.cache.repository
  if self.is_updated(name) || options.no_cache || !cache.has(name)
    let result = s:Core.get_orig_head(self.repository)
    call cache.set(name, result)
  endif
  return cache.get(name)
endfunction " }}}
function! s:git.get_merge_head(...) abort " {{{
  let options = extend({
        \ 'no_cache': 0,
        \}, get(a:000, 0, {}))
  let name = 'MERGE_HEAD'
  let cache = self.cache.repository
  if self.is_updated(name) || options.no_cache || !cache.has(name)
    let result = s:Core.get_merge_head(self.repository)
    call cache.set(name, result)
  endif
  return cache.get(name)
endfunction " }}}
function! s:git.get_cherry_pick_head(...) abort " {{{
  let options = extend({
        \ 'no_cache': 0,
        \}, get(a:000, 0, {}))
  let name = 'CHERRY_PICK_HEAD'
  let cache = self.cache.repository
  if self.is_updated(name) || options.no_cache || !cache.has(name)
    let result = s:Core.get_cherry_pick_head(self.repository)
    call cache.set(name, result)
  endif
  return cache.get(name)
endfunction " }}}
function! s:git.get_revert_head(...) abort " {{{
  let options = extend({
        \ 'no_cache': 0,
        \}, get(a:000, 0, {}))
  let name = 'REVERT_HEAD'
  let cache = self.cache.repository
  if self.is_updated(name) || options.no_cache || !cache.has(name)
    let result = s:Core.get_revert_head(self.repository)
    call cache.set(name, result)
  endif
  return cache.get(name)
endfunction " }}}
function! s:git.get_bisect_log(...) abort " {{{
  let options = extend({
        \ 'no_cache': 0,
        \}, get(a:000, 0, {}))
  let name = 'BISECT_LOG'
  let cache = self.cache.repository
  if self.is_updated(name) || options.no_cache || !cache.has(name)
    let result = s:Core.get_bisect_log(self.repository)
    call cache.set(name, result)
  endif
  return cache.get(name)
endfunction " }}}
function! s:git.get_rebase_merge_head(...) abort " {{{
  let options = extend({
        \ 'no_cache': 0,
        \}, get(a:000, 0, {}))
  let name = s:Path.join('rebase-merge', 'head-name')
  let cache = self.cache.repository
  if self.is_updated(name) || options.no_cache || !cache.has(name)
    let result = s:Core.get_rebase_merge_head(self.repository)
    call cache.set(name, result)
  endif
  return cache.get(name)
endfunction " }}}
function! s:git.get_rebase_merge_step(...) abort " {{{
  let options = extend({
        \ 'no_cache': 0,
        \}, get(a:000, 0, {}))
  let name = s:Path.join('rebase-merge', 'msgnum')
  let cache = self.cache.repository
  if self.is_updated(name) || options.no_cache || !cache.has(name)
    let result = s:Core.get_rebase_merge_step(self.repository)
    call cache.set(name, result)
  endif
  return cache.get(name)
endfunction " }}}
function! s:git.get_rebase_merge_total(...) abort " {{{
  let options = extend({
        \ 'no_cache': 0,
        \}, get(a:000, 0, {}))
  let name = s:Path.join('rebase-merge', 'end')
  let cache = self.cache.repository
  if self.is_updated(name) || options.no_cache || !cache.has(name)
    let result = s:Core.get_rebase_merge_total(self.repository)
    call cache.set(name, result)
  endif
  return cache.get(name)
endfunction " }}}
function! s:git.get_rebase_apply_head(...) abort " {{{
  let options = extend({
        \ 'no_cache': 0,
        \}, get(a:000, 0, {}))
  let name = s:Path.join('rebase-apply', 'head-name')
  let cache = self.cache.repository
  if self.is_updated(name) || options.no_cache || !cache.has(name)
    let result = s:Core.get_rebase_apply_head(self.repository)
    call cache.set(name, result)
  endif
  return cache.get(name)
endfunction " }}}
function! s:git.get_rebase_apply_step(...) abort " {{{
  let options = extend({
        \ 'no_cache': 0,
        \}, get(a:000, 0, {}))
  let name = s:Path.join('rebase-apply', 'next')
  let cache = self.cache.repository
  if self.is_updated(name) || options.no_cache || !cache.has(name)
    let result = s:Core.get_rebase_apply_step(self.repository)
    call cache.set(name, result)
  endif
  return cache.get(name)
endfunction " }}}
function! s:git.get_rebase_apply_total(...) abort " {{{
  let options = extend({
        \ 'no_cache': 0,
        \}, get(a:000, 0, {}))
  let name = s:Path.join('rebase-apply', 'last')
  let cache = self.cache.repository
  if self.is_updated(name) || options.no_cache || !cache.has(name)
    let result = s:Core.get_rebase_apply_total(self.repository)
    call cache.set(name, result)
  endif
  return cache.get(name)
endfunction " }}}

function! s:git.is_merging() abort " {{{
  " is_xxxxx just check existence, thus no cache mech. required
  return s:Core.is_merging(self.repository)
endfunction " }}}
function! s:git.is_cherry_picking() abort " {{{
  " is_xxxxx just check existence, thus no cache mech. required
  return s:Core.is_cherry_picking(self.repository)
endfunction " }}}
function! s:git.is_reverting() abort " {{{
  " is_xxxxx just check existence, thus no cache mech. required
  return s:Core.is_reverting(self.repository)
endfunction " }}}
function! s:git.is_bisecting() abort " {{{
  " is_xxxxx just check existence, thus no cache mech. required
  return s:Core.is_bisecting(self.repository)
endfunction " }}}
function! s:git.is_rebase_merging() abort " {{{
  " is_xxxxx just check existence, thus no cache mech. required
  return s:Core.is_rebase_merging(self.repository)
endfunction " }}}
function! s:git.is_rebase_merging_interactive() abort " {{{
  " is_xxxxx just check existence, thus no cache mech. required
  return s:Core.is_rebase_merging_interactive(self.repository)
endfunction " }}}
function! s:git.is_rebase_applying() abort " {{{
  " is_xxxxx just check existence, thus no cache mech. required
  return s:Core.is_rebase_applying(self.repository)
endfunction " }}}
function! s:git.is_rebase_applying_rebase() abort " {{{
  " is_xxxxx just check existence, thus no cache mech. required
  return s:Core.is_rebase_applying_rebase(self.repository)
endfunction " }}}
function! s:git.is_rebase_applying_am() abort " {{{
  " is_xxxxx just check existence, thus no cache mech. required
  return s:Core.is_rebase_applying_am(self.repository)
endfunction " }}}

function! s:git.get_mode() abort " {{{
  " Core.get_mode mainly use filereadable internally thus no cache mech. is
  " required
  return s:Core.get_mode(self.repository)
endfunction " }}}
function! s:git.get_commit_editmsg(...) abort " {{{
  let options = extend({
        \ 'no_cache': 0,
        \}, get(a:000, 0, {}))
  let name = 'COMMIT_EDITMSG'
  let cache = self.cache.repository
  if self.is_updated(name) || options.no_cache || !cache.has(name)
    let result = s:Core.get_commit_editmsg(self.repository)
    call cache.set(name, result)
  endif
  return cache.get(name)
endfunction " }}}
function! s:git.get_merge_msg(...) abort " {{{
  let options = extend({
        \ 'no_cache': 0,
        \}, get(a:000, 0, {}))
  let name = 'MERGE_MSG'
  let cache = self.cache.repository
  if self.is_updated(name) || options.no_cache || !cache.has(name)
    let result = s:Core.get_merge_msg(self.repository)
    call cache.set(name, result)
  endif
  return cache.get(name)
endfunction " }}}
function! s:git.get_local_hash(branch, ...) abort " {{{
  let options = extend({
        \ 'no_cache': 0,
        \}, get(a:000, 0, {}))
  let name = s:Path.join('refs', 'heads', a:branch)
  let cache = self.cache.repository
  if self.is_updated(name) || options.no_cache || !cache.has(name)
    let result = s:Core.get_local_hash(self.repository, a:branch)
    call cache.set(name, result)
  endif
  return cache.get(name)
endfunction " }}}
function! s:git.get_remote_hash(remote, branch, ...) abort " {{{
  let options = extend({
        \ 'no_cache': 0,
        \}, get(a:000, 0, {}))
  let name = s:Path.join('refs', 'remotes', a:remote, a:branch)
  let cache = self.cache.repository
  if self.is_updated(name) || options.no_cache || !cache.has(name)
    let result = s:Core.get_remote_hash(self.repository, a:remote, a:branch)
    call cache.set(name, result)
  endif
  return cache.get(name)
endfunction " }}}
function! s:git.get_repository_config(...) abort " {{{
  let options = extend({
        \ 'no_cache': 0,
        \}, get(a:000, 0, {}))
  let name = 'config'
  let cache = self.cache.repository
  if self.is_updated(name) || options.no_cache || !cache.has(name)
    let result = s:Core.get_repository_config(self.repository)
    call cache.set(name, result)
  endif
  return cache.get(name)
endfunction " }}}
function! s:git.get_branch_remote(branch, ...) abort " {{{
  let config = call(self.get_repository_config, a:000, self)
  return s:Core.get_branch_remote(config, a:branch)
endfunction " }}}
function! s:git.get_branch_merge(branch, ...) abort " {{{
  let config = call(self.get_repository_config, a:000, self)
  return s:Core.get_branch_merge(config, a:branch)
endfunction " }}}
function! s:git.get_remote_fetch(remote, ...) abort " {{{
  let config = call(self.get_repository_config, a:000, self)
  return s:Core.get_remote_fetch(config, a:remote)
endfunction " }}}
function! s:git.get_remote_url(remote, ...) abort " {{{
  let config = call(self.get_repository_config, a:000, self)
  return s:Core.get_remote_url(config, a:remote)
endfunction " }}}
function! s:git.get_comment_char(...) abort " {{{
  let config = call(self.get_repository_config, a:000, self)
  return s:Core.get_comment_char(config)
endfunction " }}}
function! s:git.exec(args, ...) abort " {{{
  " Note:
  "   -C might not work in old git but I'm not sure which version...
  "   In that case, I should use --git-dir/--work-tree instead.
  " Ref: https://github.com/cohama/agit.vim/issues/15
  let args = extend([
        \ '-C', self.worktree,
        \ ], a:args)
  return s:Core.exec(args, get(a:000, 0, {}))
endfunction " }}}
function! s:git.get_version() abort " {{{
  return s:Core.get_version()
endfunction " }}}

" Misc
function! s:git.get_last_commitmsg(...) abort " {{{
  let options = extend({
        \ 'no_cache': 0,
        \}, get(a:000, 0, {}))
  let cname = s:Path.join(
        \ 'index', 'last_commitmsg',
        \ string(s:Dict.omit(options, ['no_cache'])),
        \)
  let cache = self.cache.repository
  let commitmsg = (self.is_updated('index', 'last_commitmsg') || options.no_cache)
        \ ? []
        \ : cache.get(cname, [])
  if empty(commitmsg)
    let args = extend(
          \ ['log', '-1', '--pretty=%B'],
          \ get(options, 'args', []),
          \)
    let result = self.exec(args, options)
    if result.status != 0
      return result
    endif
    let commitmsg = split(result.stdout, '\v\r?\n')
    call cache.set(cname, commitmsg)
  endif
  return commitmsg
endfunction " }}}
function! s:git.count_commits_ahead_of_remote(...) abort " {{{
  let options = extend({
        \ 'no_cache': 0,
        \}, get(a:000, 0, {}))
  let cname = s:Path.join(
        \ 'index', 'commits_ahead_of_remote',
        \ string(s:Dict.omit(options, ['no_cache'])),
        \)
  let cache = self.cache.repository
  let ncommits = (self.is_updated('index', 'commits_ahead_of_remote') || options.no_cache)
        \ ? -1
        \ : cache.get(cname, -1)
  if ncommits == -1
    let args = extend(
          \ ['log', '--oneline', '@{upstream}..'],
          \ get(options, 'args', []),
          \)
    let result = self.exec(args, options)
    if result.status != 0
      return 0
    endif
    let ncommits = len(split(result.stdout, '\v\r?\n'))
    call cache.set(cname, ncommits)
  endif
  return ncommits
endfunction " }}}
function! s:git.count_commits_behind_remote(...) abort " {{{
  let options = extend({
        \ 'no_cache': 0,
        \}, get(a:000, 0, {}))
  let cname = s:Path.join(
        \ 'index', 'commits_behind_remote',
        \ string(s:Dict.omit(options, ['no_cache'])),
        \)
  let cache = self.cache.repository
  let ncommits = (self.is_updated('index', 'commits_behind_remote') || options.no_cache)
        \ ? -1
        \ : cache.get(cname, -1)
  if ncommits == -1
    let args = extend(
          \ ['log', '--oneline', '..@{upstream}'],
          \ get(options, 'args', []),
          \)
    let result = self.exec(args, options)
    if result.status != 0
      return 0
    endif
    let ncommits = len(split(result.stdout, '\v\r?\n'))
    call cache.set(cname, ncommits)
  endif
  return ncommits
endfunction " }}}

" Helper
function! s:git.get_meta() abort " {{{
  let meta = {}
  let meta.head = self.get_head()

  " commit msg
  let commit_editmsg = self.get_commit_editmsg()
  let meta.last_commitmsg = empty(commit_editmsg)
        \ ? self.get_last_commitmsg()
        \ : commit_editmsg

  " local
  let meta.local = {}
  let meta.local.name = fnamemodify(self.worktree, ':t')
  let meta.local.branch_name = meta.head =~? 'refs/heads/'
        \ ? matchstr(meta.head, 'refs/heads/\zs.\+$')
        \ : meta.head[:7]
  let meta.local.branch_hash = self.get_local_hash(meta.local.branch_name)

  " remote
  let branch_remote = self.get_branch_remote(meta.local.branch_name)
  let branch_merge  = self.get_branch_merge(meta.local.branch_name)
  let meta.remote = {}
  let meta.remote.name = branch_remote
  let meta.remote.branch_name = empty(branch_remote) ? '' :
        \ branch_merge =~? 'refs/heads/'
        \ ? matchstr(branch_merge, 'refs/heads/\zs.\+$')
        \ : branch_merge[:7]
  let meta.remote.branch_hash = self.get_remote_hash(
        \ branch_remote,
        \ meta.remote.branch_name,
        \)
  let meta.remote.url = self.get_remote_url(branch_remote)
  return meta
endfunction " }}}

let &cpo = s:save_cpo
unlet s:save_cpo
"vim: sts=2 sw=2 smarttab et ai textwidth=0 fdm=marker
