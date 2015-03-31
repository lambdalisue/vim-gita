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
function! s:_vital_loaded(V) dict abort " {{{
  let s:Dict = a:V.import('Data.Dict')
  let s:Prelude = a:V.import('Prelude')
  let s:Cache = a:V.import('System.Cache.Simple')
  let s:Core = a:V.import('VCS.Git.Core')
  let s:Misc = a:V.import('VCS.Git.Misc')
  let s:Finder = a:V.import('VCS.Git.Finder')
endfunction " }}}
function! s:_vital_depends() abort " {{{
  return [
        \ 'System.Cache.Simple',
        \ 'VCS.Git.Core',
        \ 'VCS.Git.Misc',
        \ 'VCS.Git.Finder',
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
    let s:finder_cache = s:get_config().cache.finder.new()
  endif
  return s:finder_cache
endfunction " }}}
function! s:_get_instance_cache() abort " {{{
  if !exists('s:instance_cache')
    let s:instance_cache = s:get_config().cache.instance.new()
  endif
  return s:instance_cache
endfunction " }}}

let s:config = {}
function! s:get_config() abort " {{{
  let default = {
        \ 'cache': {
        \   'finder':   s:Cache,
        \   'instance': s:Cache,
        \   'meta':     s:Cache,
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
  let git = extend(deepcopy(s:git), {
        \ 'worktree': a:worktree,
        \ 'repository': a:repository,
        \ 'cache': s:get_config().cache.meta.new(),
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
function! s:git._get_cache(name, ...) abort " {{{
  let default = get(a:000, 0, {})
  let uptime = self.get_index_updated_time()
  if uptime == -1
    " getftime is not available?
    return {}
  endif
  let cached = self.cache.get(a:name, {})
  if !empty(cached) && uptime <= get(cached, 'actime', -1)
    return cached
  endif
  return {}
endfunction " }}}
function! s:git._set_cache(name, obj) abort " {{{
  let uptime = self.get_index_updated_time()
  if uptime == -1
    let obj = { 'value': a:obj }
  else
    let obj = { 'actime': uptime, 'value': a:obj }
  endif
  call self.cache.set(a:name, obj)
  return obj
endfunction " }}}
function! s:git._get_call_opts(...) abort " {{{
  return extend({
        \ 'cwd': self.worktree,
        \}, get(a:000, 0, {}))
endfunction " }}}

function! s:git.get_index_updated_time() abort " {{{
  return s:Core.get_index_updated_time(self.repository)
endfunction " }}}
function! s:git.get_parsed_status(...) abort " {{{
  let options = self._get_call_opts(extend({
        \ 'no_cache': 0,
        \}, get(a:000, 0, {})))
  let opts = s:Dict.omit(options, ['no_cache'])
  let name = printf('status_%s', string(opts))
  let cached = self._get_cache(name)
  if !options.no_cache && !empty(cached)
    return cached.value
  endif
  let result = s:Misc.get_parsed_status(opts)
  return self._set_cache(name, result).value
endfunction " }}}
function! s:git.get_parsed_commit(...) abort " {{{
  let options = self._get_call_opts(extend({
        \ 'no_cache': 0,
        \}, get(a:000, 0, {})))
  let opts = s:Dict.omit(options, ['no_cache'])
  let name = printf('commit_%s', string(opts))
  let cached = self._get_cache(name)
  if !options.no_cache && !empty(cached)
    return cached.value
  endif
  let result = s:Misc.get_parsed_commit(opts)
  return self._set_cache(name, result).value
endfunction " }}}
function! s:git.get_parsed_config(...) abort " {{{
  let options = self._get_call_opts(extend({
        \ 'no_cache': 0,
        \}, get(a:000, 0, {})))
  let opts = s:Dict.omit(options, ['no_cache'])
  let name = printf('config_%s', string(opts))
  let cached = self._get_cache(name)
  if !options.no_cache && !empty(cached)
    return cached.value
  endif
  let result = s:Misc.get_parsed_config(opts)
  return self._set_cache(name, result).value
endfunction " }}}
function! s:git.get_meta(...) abort " {{{
  let options = extend({
        \ 'no_cache': 0,
        \}, get(a:000, 0, {}))
  let opts = s:Dict.omit(options, ['no_cache'])
  let cached = self._get_cache('meta')
  if !options.no_cache && !empty(cached)
    return cached.value
  endif
  let result = s:Misc.get_meta(self.repository, opts)
  return self._set_cache('meta', result).value
endfunction " }}}
function! s:git.get_last_commitmsg(...) abort " {{{
  let options = self._get_call_opts(extend({
        \ 'no_cache': 0,
        \}, get(a:000, 0, {})))
  let opts = s:Dict.omit(options, ['no_cache'])
  let name = printf('last_commitmsg_%s', string(opts))
  let cached = self._get_cache(name)
  if !options.no_cache && !empty(cached)
    return cached.value
  endif
  let result = s:Misc.get_last_commitmsg(opts)
  return self._set_cache(name, result).value
endfunction " }}}
function! s:git.count_commits_ahead_of_remote(...) abort " {{{
  let options = self._get_call_opts(extend({
        \ 'no_cache': 0,
        \}, get(a:000, 0, {})))
  let opts = s:Dict.omit(options, ['no_cache'])
  let name = printf('commits_ahead_of_remote_%s', string(opts))
  let cached = self._get_cache(name)
  if !options.no_cache && !empty(cached)
    return cached.value
  endif
  let result = s:Misc.count_commits_ahead_of_remote(opts)
  return self._set_cache(name, result).value
endfunction " }}}
function! s:git.count_commits_behind_remote(...) abort " {{{
  let options = self._get_call_opts(extend({
        \ 'no_cache': 0,
        \}, get(a:000, 0, {})))
  let opts = s:Dict.omit(options, ['no_cache'])
  let name = printf('commits_behind_remote_%s', string(opts))
  let cached = self._get_cache(name)
  if !options.no_cache && !empty(cached)
    return cached.value
  endif
  let result = s:Misc.count_commits_behind_remote(opts)
  return self._set_cache(name, result).value
endfunction " }}}

function! s:git.get_relative_path(path) abort " {{{
  return s:Core.get_relative_path(self.worktree, a:path)
endfunction " }}}
function! s:git.get_absolute_path(path) abort " {{{
  return s:Core.get_absolute_path(self.worktree, a:path)
endfunction " }}}

function! s:git.exec(args, ...) abort " {{{
  let opts = extend(self._get_call_opts(), get(a:000, 0, {}))
  return s:Core.exec(a:args, opts)
endfunction " }}}

function! s:git.add(options, ...) abort " {{{
  let defaults = {
        \ 'dry_run': 0,
        \ 'verbose': 0,
        \ 'force': 0,
        \ 'interactive': 0,
        \ 'patch': 0,
        \ 'edit': 0,
        \ 'update': 0,
        \ 'all': 0,
        \ 'intent_to_add': 0,
        \ 'refresh': 0,
        \ 'ignore_errors': 0,
        \ 'ignore_missing': 0,
        \} 
  let opts = s:Dict.omit(a:options, keys(defaults))
  let args = extend(['add'], s:Misc.opts2args(a:options, defaults))
  let filenames = s:_listalize(get(a:000, 0, []))
  if len(filenames) > 0
    call add(args, ['--', filenames])
  endif
  return self.exec(args, opts)
endfunction " }}}
function! s:git.rm(options, ...) abort " {{{
  let defaults = {
        \ 'force': 0,
        \ 'dry_run': 0,
        \ 'r': 0,
        \ 'cached': 0,
        \ 'ignore_unmatch': 0,
        \ 'quiet': 0,
        \} 
  let opts = s:Dict.omit(a:options, keys(defaults))
  let args = extend(['rm'], s:Misc.opts2args(a:options, defaults))
  let filenames = s:_listalize(get(a:000, 0, []))
  if len(filenames) > 0
    call add(args, ['--', filenames])
  endif
  return self.exec(args, opts)
endfunction " }}}
function! s:git.reset(options, commit, ...) abort " {{{
  let defaults = {
        \ 'quiet': 0,
        \ 'patch': 0,
        \ 'intent_to_add': 0,
        \ 'mixed': 0,
        \ 'soft': 0,
        \ 'merge': 0,
        \ 'keep': 0,
        \} 
  let opts = s:Dict.omit(a:options, keys(defaults))
  let args = extend(['reset'], s:Misc.opts2args(a:options, defaults))
  if strlen(a:commit)
    call add(args, a:commit)
  endif
  let filenames = s:_listalize(get(a:000, 0, []))
  if len(filenames) > 0
    call add(args, ['--', filenames])
  endif
  return self.exec(args, opts)
endfunction " }}}
function! s:git.checkout(options, commit, ...) abort " {{{
  let defaults = {
        \ 'quiet': 0,
        \ 'force': 0,
        \ 'ours': 0,
        \ 'theirs': 0,
        \ 'b': '',
        \ 'B': '',
        \ 'track': 0,
        \ 'no_track': 0,
        \ 'l': 0,
        \ 'detach': 0,
        \ 'orphan': '',
        \ 'merge': 0,
        \ 'conflict': '=merge',
        \ 'patch': 0,
        \} 
  let opts = s:Dict.omit(a:options, keys(defaults))
  let args = extend(['checkout'], s:Misc.opts2args(a:options, defaults))
  if strlen(a:commit)
    call add(args, a:commit)
  endif
  let filenames = s:_listalize(get(a:000, 0, []))
  if len(filenames) > 0
    call add(args, ['--', filenames])
  endif
  return self.exec(args, opts)
endfunction " }}}
function! s:git.status(options, ...) abort " {{{
  let defaults = {
        \ 'short': 0,
        \ 'branch': 0,
        \ 'porcelain': 0,
        \ 'untracked_files': '=all',
        \ 'ignore_submodules': '=all',
        \ 'ignored': 0,
        \ 'z': 0,
        \} 
  let opts = s:Dict.omit(a:options, keys(defaults))
  let args = extend(['status'], s:Misc.opts2args(a:options, defaults))
  let filenames = s:_listalize(get(a:000, 0, []))
  if len(filenames) > 0
    call add(args, ['--', filenames])
  endif
  return self.exec(args, opts)
endfunction " }}}
function! s:git.commit(options, ...) abort " {{{
  let defaults = {
        \ 'all': 0,
        \ 'patch': 0,
        \ 'reuse_message': '=',
        \ 'reedit_message': '=',
        \ 'fixup': '=',
        \ 'squash': '=',
        \ 'reset_author': 0,
        \ 'short': 0,
        \ 'porcelain': 0,
        \ 'z': 0,
        \ 'file': '=',
        \ 'author': '=',
        \ 'date': '=',
        \ 'message': '=',
        \ 'template': '=',
        \ 'signoff': 0,
        \ 'no_verify': 0,
        \ 'allow_empty': 0,
        \ 'allow_empty_message': 0,
        \ 'cleanup': '=default',
        \ 'edit': 0,
        \ 'amend': 0,
        \ 'include': 0,
        \ 'only': 0,
        \ 'untracked_files': '=all',
        \ 'verbose': 0,
        \ 'quiet': 0,
        \ 'dry_run': 0,
        \ 'status': 0,
        \ 'no_status': 0,
        \} 
  let opts = s:Dict.omit(a:options, keys(defaults))
  let args = extend(['commit'], s:Misc.opts2args(a:options, defaults))
  let filenames = s:_listalize(get(a:000, 0, []))
  if len(filenames) > 0
    call add(args, ['--', filenames])
  endif
  return self.exec(args, opts)
endfunction " }}}
function! s:git.diff(options, commit, ...) abort " {{{
  let defaults = {
        \ 'patch': 0,
        \ 'unified': '=',
        \ 'raw': 0,
        \ 'patch_with_raw': 0,
        \ 'minimal': 0,
        \ 'patience': 0,
        \ 'histogram': 0,
        \ 'stat': '=',
        \ 'numstat': 0,
        \ 'shortstat': 0,
        \ 'dirstat': '=',
        \ 'summary': 0,
        \ 'patch_with_stat': 0,
        \ 'z': 0,
        \ 'name_only': 0,
        \ 'name_status': 0,
        \ 'submodule': '=log',
        \ 'color': '=never',
        \ 'no_color': 0,
        \ 'word_diff': '=plain',
        \ 'word_diff_regex': '=',
        \ 'color_words': '=',
        \ 'no_renames': 0,
        \ 'check': 0,
        \ 'full_index': 0,
        \ 'binary': 0,
        \ 'abbrev': '=',
        \ 'break_rewrites': '=',
        \ 'find_renames': '=',
        \ 'find_copies': '=',
        \ 'find_copies_harder': 0,
        \ 'irreversible_delete': 0,
        \ 'l': '=',
        \ 'diff_filter': '=',
        \ 'S': '=',
        \ 'G': '=',
        \ 'pickaxe_all': 0,
        \ 'pickaxe_regex': 0,
        \ 'O': '=',
        \ 'R': 0,
        \ 'relative': '=',
        \ 'text': 0,
        \ 'ignore_space_at_eol': 0,
        \ 'ignore_space_change': 0,
        \ 'ignore_all_space': 0,
        \ 'inter_hunk_context': '=',
        \ 'function_context': 0,
        \ 'exit_code': 0,
        \ 'quiet': 0,
        \ 'ext_diff': 0,
        \ 'no_ext_diff': 0,
        \ 'textconv': 0,
        \ 'no_textconv': 0,
        \ 'ignore_submodules': '=all',
        \ 'src_prefix': '=',
        \ 'dst_prefix': '=',
        \ 'no_prefix': 0,
        \} 
  let opts = s:Dict.omit(a:options, keys(defaults))
  let args = extend(['diff'], s:Misc.opts2args(a:options, defaults))
  if get(a:options, 'cached', 0)
    call add(args, '--cached')
  endif
  if strlen(a:commit) > 0
    call add(args, a:commit)
  endif
  let filenames = s:_listalize(get(a:000, 0, []))
  if len(filenames) > 0
    call add(args, ['--', filenames])
  endif
  return self.exec(args, opts)
endfunction " }}}

let &cpo = s:save_cpo
unlet s:save_cpo
"vim: sts=2 sw=2 smarttab et ai textwidth=0 fdm=marker
