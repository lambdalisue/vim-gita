function! s:_vital_loaded(V) abort
  let s:Prelude = a:V.import('Prelude')
  let s:Process = a:V.import('Process')
  let s:List = a:V.import('Data.List')
  let s:Dict = a:V.import('Data.Dict')
  let s:Path = a:V.import('System.Filepath')
  let s:DummyCache = a:V.import('System.Cache.Dummy')
  let s:MemoryCache = a:V.import('System.Cache.Memory')
  let s:INI = a:V.import('Text.INI')
  let s:StringExt = a:V.import('Data.String.Extra')
  let s:Finder = a:V.import('Git.Finder')
  let s:Util = a:V.import('Git.Util')
  let s:Operation = a:V.import('Git.Operation')
  let s:config = {
        \ 'executable': 'git',
        \ 'arguments': ['-c', 'color.ui=false', '--no-pager'],
        \ 'instance_cache': {
        \   'class': s:MemoryCache,
        \   'options': {},
        \ },
        \ 'repository_cache': {
        \   'class': s:MemoryCache,
        \   'options': {},
        \ },
        \ 'exception_prefix': 'vital: Git: ',
        \}
  if !exists('s:SEPARATOR')
    let s:SEPARATOR = s:Path.separator()
    lockvar s:SEPARATOR
  endif
endfunction
function! s:_vital_depends() abort
  return [
        \ 'Prelude',
        \ 'Process',
        \ 'Data.List',
        \ 'Data.Dict',
        \ 'System.Filepath',
        \ 'System.Cache.Dummy',
        \ 'System.Cache.Memory',
        \ 'Text.INI',
        \ 'Data.String.Extra',
        \ 'Git.Finer',
        \ 'Git.Util',
        \ 'Git.Operation',
        \]
endfunction
function! s:_vital_created(module) abort
endfunction

function! s:_throw(msg) abort
  throw s:config.exception_prefix . a:msg
endfunction

function! s:get_config() abort
  return copy(s:config)
endfunction
function! s:set_config(config) abort
  let config = s:Dict.pick(a:config, [
        \ 'executable',
        \ 'arguments',
        \])
  call extend(s:config, config)
endfunction
function! s:_create_cache_instance(config) abort
  return a:config.class.new(get(a:config, 'options', {}))
endfunction
function! s:_get_instance_cache() abort
  if !exists('s:_instance_cache')
    let s:_instance_cache = s:_create_cache_instance(s:config.instance_cache)
  endif
  return s:_instance_cache
endfunction
function! s:_get_repository_cache() abort
  " NOTE:
  " Always return a fresh instance
  return s:_create_cache_instance(s:config.repository_cache)
endfunction

function! s:get_relative_path(git, path) abort
  let path = s:Path.realpath(a:path)
  if s:Path.is_relative(path)
    return path
  endif
  let prefix = s:StringExt.escape_regex(
        \ a:git.worktree[-1] ==# s:SEPARATOR
        \   ? expand(a:git.worktree)
        \   : expand(a:git.worktree) . s:SEPARATOR
        \)
  return substitute(expand(path), '^' . prefix, '', '')
endfunction
function! s:get_absolute_path(git, path) abort
  let path = s:Path.realpath(a:path)
  if s:Path.is_absolute(path)
    return path
  endif
  return s:Path.join(a:git.worktree, path)
endfunction

function! s:readfile(git, path) abort
  return s:Util.readfile(s:Path.join(a:git.repository, a:path))
endfunction
function! s:readline(git, path) abort
  return s:Util.readline(s:Path.join(a:git.repository, a:path))
endfunction
function! s:filereadable(git, path) abort
  return filereadable(s:Path.join(a:git.repository, a:path))
endfunction
function! s:isdirectory(git, path) abort
  return isdirectory(s:Path.join(a:git.repository, a:path))
endfunction
function! s:getftime(git, path) abort
  return getftime(s:Path.join(a:git.repository, a:path))
endfunction

function! s:get_head(git) abort
  return s:readline(a:git, 'HEAD')
endfunction
function! s:get_fetch_head(git) abort
  return s:readline(a:git, 'FETCH_HEAD')
endfunction
function! s:get_orig_head(git) abort
  return s:readline(a:git, 'ORIG_HEAD')
endfunction
function! s:get_merge_head(git) abort
  return s:readline(a:git, 'MERGE_HEAD')
endfunction
function! s:get_cherry_pick_head(git) abort
  return s:readline(a:git, 'CHERRY_PICK_HEAD')
endfunction
function! s:get_revert_head(git) abort
  return s:readline(a:git, 'REVERT_HEAD')
endfunction
function! s:get_bisect_log(git) abort
  return s:readline(a:git, 'BISECT_LOG')
endfunction
function! s:get_rebase_merge_head(git) abort
  return s:readline(a:git, 'rebase-merge', 'head-name')
endfunction
function! s:get_rebase_merge_step(git) abort
  return s:readline(a:git, 'rebase-merge', 'msgnum')
endfunction
function! s:get_rebase_merge_total(git) abort
  return s:readline(a:git, 'rebase-merge', 'end')
endfunction
function! s:get_rebase_apply_head(git) abort
  return s:readline(a:git, 'rebase-apply', 'head-name')
endfunction
function! s:get_rebase_apply_step(git) abort
  return s:readline(a:git, 'rebase-apply', 'next')
endfunction
function! s:get_rebase_apply_total(git) abort
  return s:readline(a:git, 'rebase-apply', 'last')
endfunction
function! s:get_commit_editmsg(git) abort
  return s:readfile(a:git, 'COMMIT_EDITMSG')
endfunction
function! s:get_merge_msg(git) abort
  return s:readfile(a:git, 'MERGE_MSG')
endfunction

function! s:is_merging(git) abort
  return s:filereadable(a:git, 'MERGE_HEAD')
endfunction
function! s:is_cherry_picking(git) abort
  return s:filereadable(a:git, 'CHERRY_PICK_HEAD')
endfunction
function! s:is_reverting(git) abort
  return s:filereadable(a:git, 'REVERT_HEAD')
endfunction
function! s:is_bisecting(git) abort
  return s:filereadable(a:git, 'BISECT_LOG')
endfunction
function! s:is_rebase_merging(git) abort
  return s:isdirectory(a:git, 'rebase-merge')
endfunction
function! s:is_rebase_merging_interactive(git) abort
  return s:filereadable(a:git, 'rebase-merge', 'interactive')
endfunction
function! s:is_rebase_applying(git) abort
  return s:isdirectory(a:git, 'rebase-apply')
endfunction
function! s:is_rebase_applying_rebase(git) abort
  return s:filereadable(a:git, 'rebase-apply', 'rebasing')
endfunction
function! s:is_rebase_applying_am(git) abort
  return s:filereadable(a:git, 'rebase-apply', 'applying')
endfunction
function! s:get_current_mode(git) abort
  " https://github.com/git/git/blob/dd160d7/contrib/completion/git-prompt.sh#L391-L460
  if s:is_rebase_merging(a:git)
    let step  = s:get_rebase_merge_step(a:git)
    let total = s:get_rebase_merge_total(a:git)
    if s:is_rebase_merging_interactive(a:git)
      return printf('REBASE-i %d/%d', step, total)
    else
      return printf('REBASE-m %d/%d', step, total)
    endif
  else
    if s:is_rebase_applying(a:git)
      let step  = s:get_rebase_apply_step(a:git)
      let total = s:get_rebase_apply_total(a:git)
      if s:is_rebase_applying_rebase(a:git)
        return printf('REBASE %d/%d', step, total)
      elseif s:is_rebase_applying_am(a:git)
        return printf('AM %d/%d', step, total)
      else
        return printf('AM/REBASE %d/%d', step, total)
      endif
    elseif s:is_merging(a:git)
      return 'MERGING'
    elseif s:is_cherry_picking(a:git)
      return 'CHERRY-PICKING'
    elseif s:is_reverting(a:git)
      return 'REVERTING'
    elseif s:is_bisecting(a:git)
      return 'BISECTING'
    endif
  endif
  return ''
endfunction

" *** Cache ******************************************************************
function! s:get_cached_content(git, path, slug, ...) abort
  let slug = get(a:000, 0, '')
  let path = s:Path.realpath(a:path)
  let uptime = s:getftime(a:git, path)
  let cached = a:git.repository_cache.get(a:slug . ':' . path, {})
  return empty(cached) || uptime == -1 || uptime > cached.uptime
        \ ? get(a:000, 0, '')
        \ : cached.content
endfunction
function! s:set_cached_content(git, path, slug, content) abort
  let path = s:Path.realpath(a:path)
  let uptime = s:getftime(a:git, path)
  call a:git.repository_cache.set(a:slug . ':' . path, {
        \ 'uptime': uptime,
        \ 'content': a:content,
        \})
endfunction

" *** Time consuming *********************************************************
function! s:get_repository_config(git) abort
  let slug = 'get_repository_config'
  let content = s:get_cached_content(a:git, 'config', slug, {})
  if empty(content)
    let filename = s:Path.join(a:git.repository, 'config')
    if filereadable(filename)
      let content = s:INI.parse_file(filename)
    endif
    call s:set_cached_content(a:git, 'config', slug, content)
  endif
  return content
endfunction " }}}
function! s:get_branch_remote(config, local_branch) abort
  " a name of remote which the {local_branch} connect
  let section = get(a:config, printf('branch "%s"', a:local_branch), {})
  if empty(section)
    return ''
  endif
  return get(section, 'remote', '')
endfunction
function! s:get_branch_merge(config, local_branch, ...) abort
  " a branch name of remote which {local_branch} connect
  let truncate = get(a:000, 0, 0)
  let section = get(a:config, printf('branch "%s"', a:local_branch), {})
  if empty(section)
    return ''
  endif
  let merge = get(section, 'merge', '')
  return truncate ? substitute(merge, '\v^refs/heads/', '', '') : merge
endfunction
function! s:get_remote_fetch(config, remote) abort
  " a url of {remote}
  let section = get(a:config, printf('remote "%s"', a:remote), {})
  if empty(section)
    return ''
  endif
  return get(section, 'fetch', '')
endfunction
function! s:get_remote_url(config, remote) abort
  " a url of {remote}
  let section = get(a:config, printf('remote "%s"', a:remote), {})
  if empty(section)
    return ''
  endif
  return get(section, 'url', '')
endfunction
function! s:get_comment_char(config, ...) abort
  let default = get(a:000, 0, '#')
  let section = get(a:config, 'core', {})
  if empty(section)
    return default
  endif
  return get(section, 'commentchar', default)
endfunction

function! s:resolve_ref(git, ref) abort
  let slug = 'resolve_ref'
  let content = s:get_cached_content(a:git, a:ref, slug)
  if empty(content)
    let filename = s:Path.join(a:git.repository, a:ref)
    let content = s:Util.readline(filename)
    if content =~# '^ref:\s'
      " recursively resolve ref
      return s:resolve_ref(
            \ a:git.repository,
            \ substitute(content, '^ref:\s', '', ''),
            \)
    elseif empty(content)
      " ref is missing in traditional directory, the ref should be written in
      " packed-ref then
      let filename = s:Path.join(a:git.repository, 'packed-refs')
      let filter_code = printf(
            \ 'v:val[0] !=# "#" && v:val[-%d:] ==# a:ref',
            \ len(a:ref)
            \)
      let packed_refs = filter(s:Util.readfile(filename), filter_code)
      let content = get(split(get(packed_refs, 0, '')), 0, '')
    endif
    call s:set_cached_content(a:git, a:ref, slug, content)
  endif
  return content
endfunction
function! s:get_local_hash(git, branch) abort
  if a:branch =~# 'HEAD'
    let HEAD = s:get_head(a:git)
    let ref = s:Path.join(
          \ a:git.repository,
          \ substitute(HEAD, '^ref:\s', '', ''),
          \)
  else
    let ref = s:Path.join('refs', 'heads', a:branch)
  endif
  return s:resolve_ref(a:git, ref)
endfunction
function! s:get_remote_hash(git, remote, branch) abort
  let ref = s:Path.join('refs', 'remotes', a:remote, a:branch)
  return s:resolve_ref(a:git, ref)
endfunction

function! s:get_local_branch(git) abort
  let head = s:get_head(a:git)
  let branch_name = head =~# 'refs/heads/'
        \ ? matchstr(head, 'refs/heads/\zs/.\+$')
        \ : head[:7]
  let branch_hash = s:get_local_hash(a:git, branch_name)
  return {
        \ 'name': branch_name,
        \ 'hash': branch_hash,
        \}
endfunction
function! s:get_remote_branch(git) abort
  let config = s:get_repository_config(a:git)
  if empty(config)
    return { 'name': '', 'hash': '', 'url': '' }
  endif
  let local = s:get_local_branch(a:git)
  let merge = s:get_branch_merge(config, local.name)
  let remote = s:get_branch_remote(config, local.name)
  let remote_url = s:get_remote_url(config, remote)
  let branch_name = merge =~# 'refs/heads/'
        \ ? matchstr(merge, 'refs/heads/\zs.\+$')
        \ : merge[:7]
  let branch_hash = s:get_remote_hash(a:git, remote, branch_name)
  return {
        \ 'remote': remote,
        \ 'name': branch_name,
        \ 'hash': branch_hash,
        \ 'url': remote_url,
        \}
endfunction

" *** External process *******************************************************
function! s:system(args, ...) abort
  let options = extend({
        \ 'input': '',
        \ 'timeout': 0,
        \ 'content': 1,
        \ 'remove_ansi_sequences': 0,
        \ 'remove_trailing_emptyline': 0,
        \}, get(a:000, 0, {}))
  if empty(options.input)
    unlet options.input
  else
    let options.input = options.input
  endif
  let args = [s:config.executable] + s:config.arguments + a:args
  let stdout = s:Process.system(args, options)
  if options.remove_ansi_sequences
    let stdout = s:StringExt.remove_ansi_sequences(stdout)
  endif
  if options.remove_trailing_emptyline
    let stdout = s:StringExt.remove_trailing_emptyline(stdout)
  endif
  let result = {
        \ 'args': args,
        \ 'stdout': stdout,
        \ 'status': s:Process.get_last_status(),
        \}
  if options.content
    let result['content'] = split(stdout, '\r\?\n', 1)
  endif
  return result
endfunction
function! s:get_git_version() abort
  let result = s:system(['--version'])
  if result.status
    return '0.0.0'
  endif
  return matchstr(result.stdout, '^git version \zs.*$')
endfunction
function! s:get_last_commitmsg(git) abort
  if !s:filereadable(a:git, 'index')
    return []
  endif
  let slug = 'get_last_commitmsg'
  let content = s:get_cached_content(a:git, 'index', slug, [])
  if empty(content)
    let args = ['log', '-1', '--pretty=%B']
    let result = s:Operation.system(a:git, args)
    if result.status
      call s:_throw(result.stdout)
    endif
    let content = result.content
    call s:set_cached_content(a:git, 'index', slug, content)
  endif
  return content
endfunction
function! s:count_commits_ahead_of_remote(git) abort
  if !s:filereadable(a:git, 'index')
    return ''
  endif
  let slug = 'count_commits_ahead_of_remote'
  let content = s:get_cached_content(a:git, 'index', slug, -1)
  if content == -1
    let args = ['log', '--oneline', '@{upstream}..']
    let result = s:Operation.system(a:git, args)
    if result.status
      call s:_throw(result.stdout)
    endif
    let content = len(result.content)
    call s:set_cached_content(a:git, 'index', slug, content)
  endif
  return content
endfunction
function! s:count_commits_behind_remote(git) abort
  if !s:filereadable(a:git, 'index')
    return ''
  endif
  let slug = 'count_commits_behind_remote'
  let content = s:get_cached_content(a:git, 'index', slug, -1)
  if content == -1
    let args = ['log', '--oneline', '..@{upstream}']
    let result = s:Operation.system(a:git, args)
    if result.status
      call s:_throw(result.stdout)
    endif
    let content = len(result.content)
    call s:set_cached_content(a:git, 'index', slug, content)
  endif
  return content
endfunction


" *** Git instance ***********************************************************
let s:git = {}
function! s:_new(meta) abort
  let git = deepcopy(s:git)
  if empty(a:meta.worktree)
    let git.is_enabled = 0
    let git.worktree = ''
    let git.repository = ''
    let git.repository_name = ''
    let git.repository_cache = s:DummyCache.new()
  else
    let git.is_enabled = 1
    let git.worktree = a:meta.worktree
    let git.repository = a:meta.repository
    let git.repository_name = fnamemodify(a:meta.worktree, ':t')
    let git.repository_cache = s:_get_repository_cache()
  endif
  return git
endfunction
function! s:get(path, ...) abort
  let options = extend({
        \ 'force': 0,
        \}, get(a:000, 0, {}))
  let path = s:Path.abspath(s:Path.realpath(
        \ empty(a:path) ? getcwd() : a:path
        \))
  let instance_cache = s:_get_instance_cache()
  let uptime = getftime(path)
  let cached = instance_cache.get(path, {})
  if options.force || empty(cached) || uptime == -1 || uptime > cached.uptime
    let meta = s:Finder.find(path)
    if empty(meta.worktree)
      let git = s:_new(meta)
    else
      let uptime = getftime(meta.worktree)
      let cached = instance_cache.get(meta.worktree, {})
      if options.force || empty(cached) || uptime == -1 || uptime > cached.uptime
        let git = s:_new(meta)
        call instance_cache.set(meta.worktree, {
              \ 'uptime': getftime(meta.worktree),
              \ 'git': git,
              \})
      else
        let git = cached.git
      endif
    endif
    call instance_cache.set(path, {
          \ 'uptime': getftime(path),
          \ 'git': git,
          \})
  else
    let git = cached.git
  endif
  return git
endfunction
function! s:clear_instance_cache() abort
  let instance_cache = s:_get_instance_cache()
  call instance_cache.clear()
endfunction
