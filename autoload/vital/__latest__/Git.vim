function! s:_vital_loaded(V) abort
  let s:Dict = a:V.import('Data.Dict')
  let s:Path = a:V.import('System.Filepath')
  let s:DummyCache = a:V.import('System.Cache.Dummy')
  let s:MemoryCache = a:V.import('System.Cache.Memory')
  let s:StringExt = a:V.import('Data.StringExt')
  let s:config = {
        \ 'instance_cache': {
        \   'class': s:MemoryCache,
        \   'options': {},
        \ },
        \ 'repository_cache': {
        \   'class': s:MemoryCache,
        \   'options': {},
        \ },
        \}
endfunction
function! s:_vital_depends() abort
  return [
        \ 'Data.Dict',
        \ 'System.Filepath',
        \ 'System.Cache.Dummy',
        \ 'System.Cache.Memory',
        \ 'Data.StringExt',
        \]
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

function! s:get_config() abort
  return copy(s:config)
endfunction
function! s:set_config(config) abort
  let config = s:Dict.pick(a:config, [
        \ 'instance_cache',
        \ 'repository_cache',
        \])
  call extend(s:config, config)
endfunction

function! s:readfile(git, path) abort
  let path = s:Path.join(
        \ a:git.repository,
        \ s:Path.relpath(s:Path.realpath(a:path)),
        \)
  return filereadable(path) ? readfile(path) : []
endfunction
function! s:readline(git, path) abort
  return get(s:readfile(a:git, a:path), 0, '')
endfunction
function! s:filereadable(git, path) abort
  let path = s:Path.join(
        \ a:git.repository,
        \ s:Path.relpath(s:Path.realpath(a:path)),
        \)
  return filereadable(path)
endfunction
function! s:isdirectory(git, path) abort
  let path = s:Path.join(
        \ a:git.repository,
        \ s:Path.relpath(s:Path.realpath(a:path)),
        \)
  return isdirectory(path)
endfunction
function! s:getftime(git, path) abort
  let path = s:Path.join(
        \ a:git.repository,
        \ s:Path.relpath(s:Path.realpath(a:path)),
        \)
  return getftime(path)
endfunction

function! s:get_relative_path(git, path) abort
  let path = s:Path.realpath(a:path)
  if s:Path.is_relative(path)
    return path
  endif
  let prefix = s:StringExt.escape_regex(
        \ a:git.worktree[-1] ==# s:Path.separator()
        \   ? expand(a:git.worktree)
        \   : expand(a:git.worktree) . s:Path.separator()
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

function! s:get_cache_content(git, path, slug, ...) abort
  let path   = s:Path.relpath(s:Path.realpath(a:path))
  let uptime = s:getftime(a:git, path)
  let cached = a:git.repository_cache.get(a:slug . ':' . path, {})
  return empty(cached) || uptime == -1 || uptime > cached.uptime
        \ ? get(a:000, 0)
        \ : cached.content
endfunction
function! s:set_cache_content(git, path, slug, content) abort
  let path   = s:Path.relpath(s:Path.realpath(a:path))
  let uptime = s:getftime(a:git, path)
  call a:git.repository_cache.set(a:slug . ':' . path, {
        \ 'uptime': uptime,
        \ 'content': a:content,
        \})
endfunction

function! s:_fnamemodify(path, mods) abort
  if empty(a:path)
    return ''
  endif
  return s:Path.remove_last_separator(fnamemodify(a:path, a:mods))
endfunction
function! s:_find_worktree(dirpath) abort
  let dgit = s:_fnamemodify(finddir('.git', a:dirpath . ';'), ':p:h')
  let fgit = s:_fnamemodify(findfile('.git', a:dirpath . ';'), ':p')
  " inside '.git' directory is not a working directory
  let dgit = a:dirpath =~# '^' . s:StringExt.escape_regex(dgit) ? '' : dgit
  " use deepest dotgit found
  let dotgit = strlen(dgit) >= strlen(fgit) ? dgit : fgit
  return strlen(dotgit) ? s:_fnamemodify(dotgit, ':h') : ''
endfunction
function! s:_find_repository(worktree) abort
  let dotgit = s:Path.join([s:_fnamemodify(a:worktree, ':p'), '.git'])
  if isdirectory(dotgit)
    return dotgit
  elseif filereadable(dotgit)
    " in case if the found '.git' is a file which was created via
    " '--separate-git-dir' option
    let lines = readfile(dotgit)
    if !empty(lines)
      let gitdir = matchstr(lines[0], '^gitdir:\s*\zs.\+$')
      let is_abs = s:Path.is_absolute(gitdir)
      return s:_fnamemodify((is_abs ? gitdir : dotgit[:-5] . gitdir), ':p:h')
    endif
  endif
  return ''
endfunction
function! s:_find(path) abort
  if empty(a:path)
    return {'worktree': '', 'repository': ''}
  endif
  let abspath = s:Path.abspath(s:Path.realpath(a:path))
  let dirpath = isdirectory(abspath) ? abspath : fnamemodify(abspath, ':h')
  let worktree = s:_find_worktree(dirpath)
  let repository = strlen(worktree) ? s:_find_repository(worktree) : ''
  let meta = {
        \ 'worktree': worktree,
        \ 'repository': repository,
        \}
  return meta
endfunction
function! s:_new(meta) abort
  let git = {}
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
    let meta = s:_find(path)
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
function! s:clear() abort
  let instance_cache = s:_get_instance_cache()
  call instance_cache.clear()
endfunction