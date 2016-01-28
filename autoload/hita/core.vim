let s:V = hita#vital()
let s:Path = s:V.import('System.Filepath')
let s:Cache = s:V.import('System.Cache.Memory')
let s:Compat = s:V.import('Vim.Compat')
let s:Git = s:V.import('VCS.Git')

function! s:get_repository_cache() abort
  if !exists('s:repository_cache')
    let s:repository_cache = s:Cache.new()
  endif
  return s:repository_cache
endfunction

function! s:get_git_instance(expr) abort
  let bufname = bufname(a:expr)
  let buftype = s:Compat.getbufvar(a:expr, '&buftype')
  let repository_cache = s:get_repository_cache()
  if bufname =~# '^hita://' || bufname =~# '^hita[^:]\+:'
    " hita buffer
    let repository_name = matchstr(
          \ bufname, '^hita:\%(//\)\?\zs[^:/]\+\ze'
          \)
    let git = repository_cache.get(repository_name, {})
  elseif buftype =~# '^\|nowrite\|acwrite$'
    " file buffer
    let filename = hita#core#expand(a:expr)
    let git = s:Git.find(filename)
    let git = empty(git)
          \ ? s:Git.find(resolve(filename))
          \ : git
  else
    " non file buffer
    let git = s:Git.find(getcwd())
  endif
  " register git instance
  if !empty(git)
    let git.repository_name = fnamemodify(git.worktree, ':t')
    call repository_cache.set(git.repository_name, git)
  endif
  return git
endfunction
function! s:get_hita_instance(expr) abort
  let git = s:get_git_instance(a:expr)
  let hita = extend(deepcopy(s:hita), {
        \ 'enabled': !empty(git),
        \ 'bufname': bufname(a:expr),
        \ 'bufnum':  bufnr(a:expr),
        \ 'cwd':     getcwd(),
        \ 'git':     git,
        \})
  if bufexists(a:expr)
    call setbufvar(a:expr, '_hita', hita)
  endif
  return hita
endfunction
function! s:get_meta_instance(expr) abort
  let bufnum = bufnr(a:expr)
  let meta = s:Compat.getbufvar(bufnum, '_hita_meta', {})
  if bufexists(bufnum)
    call setbufvar(bufnum, '_hita_meta', meta)
  endif
  return meta
endfunction
function! s:is_hita_expired(hita) abort
  let bufname = bufname(a:hita.bufnum)
  let buftype = s:Compat.getbufvar(a:hita.bufnum, '&buftype')
  if buftype =~# '^\|nowrite\|acwrite$' && bufname !=# a:hita.bufname
    " filename has changed on file like buffer
    return 1
  elseif buftype=~# '^nofile\|quickfix\|help$' && getcwd() !=# a:hita.cwd
    " current working directory has changed on non file buffer
    return 1
  endif
  return 0
endfunction

function! hita#core#get(...) abort
  let expr = get(a:000, 0, '%')
  let hita = s:Compat.getbufvar(expr, '_hita', {})
  if !empty(hita) && !s:is_hita_expired(hita)
    return hita
  endif
  return s:get_hita_instance(expr)
endfunction
function! hita#core#get_meta(name, ...) abort
  " WARNING:
  " DO NOT USE 'hita' instance in this method.
  let expr = get(a:000, 1, '%')
  let meta = s:get_meta_instance(expr)
  return get(meta, a:name, get(a:000, 0, ''))
endfunction
function! hita#core#set_meta(name, value, ...) abort
  " WARNING:
  " DO NOT USE 'hita' instance in this method.
  let expr = get(a:000, 0, '%')
  let meta = s:get_meta_instance(expr)
  let meta[a:name] = a:value
endfunction
function! hita#core#expand(expr) abort
  " WARNING:
  " DO NOT USE 'hita' instance in this method.
  if empty(a:expr)
    return ''
  endif
  let meta_filename = hita#core#get_meta('filename', '', a:expr)
  let real_filename = expand(a:expr)
  let filename = empty(meta_filename) ? real_filename : meta_filename
  " NOTE:
  " Always return a real absolute path
  return s:Path.abspath(s:Path.realpath(filename))
endfunction

let s:hita = {}
function! s:hita.is_enabled() abort
  return self.enabled
endfunction
function! s:hita.fail_on_disabled() abort
  if !self.is_enabled()
    call hita#throw('Cancel: Hita is not available on the buffer')
  endif
endfunction
function! s:hita.get_repository_name() abort
  return self.is_enabled()
        \ ? self.git.repository_name
        \ : 'not-in-repository'
endfunction
function! s:hita.get_relative_path(path) abort
  " NOTE:
  " Return a unix relative path from the repository for git command
  " {path} requires to be a (real) absolute paht
  if empty(a:path)
    return ''
  endif
  let realpath = s:Path.realpath(a:path)
  let relpath = self.git.get_relative_path(realpath)
  return s:Path.unixpath(relpath)
endfunction
