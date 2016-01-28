let s:V = vital#of('vim_gita')
let s:Path = s:V.import('System.Filepath')
let s:Compat = s:V.import('Vim.Compat')
let s:MemoryCache = s:V.import('System.Cache.Memory')
let s:Git = s:V.import('Git')
let s:Operation = s:V.import('Git.Operation')

function! s:get_repository_cache() abort
  if !exists('s:repository_cache')
    let s:repository_cache = s:MemoryCache.new()
  endif
  return s:repository_cache
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
function! s:get_git_instance(bufnum) abort
  let bufname = bufname(a:bufnum)
  let buftype = s:Compat.getbufvar(a:bufnum, '&buftype')
  let repository_cache = s:get_repository_cache()
  if bufname =~# '^hita://' || bufname =~# '^hita[^:]\+:'
    " hita buffer
    let repository_name = matchstr(
          \ bufname, '^hita[^:]*:\%(//\)\?\zs[^:/]\+\ze'
          \)
    let git = repository_cache.get(repository_name, {})
    return git
  elseif buftype =~# '^\|nowrite\|acwrite$'
    " file buffer
    let filename = hita#expand(a:bufnum)
    let git = s:Git.get(filename)
    let git = git.is_enabled ? git : s:Git.get(resolve(filename))
    let git = git.is_enabled ? git : s:Git.get(getcwd())
  else
    " non file buffer
    let git = s:Git.get(getcwd())
  endif
  " register git instance
  if git.is_enabled
    call repository_cache.set(git.repository_name, git)
  endif
  return git
endfunction
function! s:get_hita_instance(bufnum) abort
  let git = s:get_git_instance(a:bufnum)
  let hita = extend(deepcopy(git), {
        \ 'bufnum':  bufnr(a:bufnum),
        \ 'bufname': bufname(a:bufnum),
        \ 'cwd':     getcwd(),
        \})
  if bufexists(a:bufnum)
    call setbufvar(a:bufnum, '_hita', hita)
  endif
  return hita
endfunction
function! s:get_meta_instance(bufnum) abort
  let meta = s:Compat.getbufvar(a:bufnum, '_hita_meta', {})
  if bufexists(a:bufnum)
    call setbufvar(a:bufnum, '_hita_meta', meta)
  endif
  return meta
endfunction

function! hita#get(...) abort
  let expr = get(a:000, 0, '%')
  let bufnum = bufnr(expr)
  let hita = s:Compat.getbufvar(bufnum, '_hita', {})
  if !empty(hita) && !s:is_hita_expired(hita)
    return hita
  endif
  return s:get_hita_instance(bufnum)
endfunction
function! hita#get_or_fail(...) abort
  let expr = get(a:000, 0, '%')
  let hita = hita#get(expr)
  if hita.is_enabled
    return hita
  endif
  call hita#throw(printf(
        \ 'Cancel: vim-hita is not available on %s', bufname(expr)
        \))
endfunction
function! hita#clear_cache() abort
  let repository_cache = s:get_repository_cache()
  call repository_cache.clear()
  call s:Git.clear_instance_cache()
endfunction

function! hita#execute(hita, name, ...) abort
  let options = get(a:000, 0, {})
  let config  = get(a:000, 1, {})
  return s:Operation.execute(a:hita, a:name, options, config)
endfunction
function! hita#get_relative_path(hita, path) abort
  " NOTE:
  " Return a unix relative path from the repository for git command.
  " The {path} requires to be a (real) absolute paht.
  if empty(a:path)
    return ''
  endif
  let relpath = s:Git.get_relative_path(a:hita, a:path)
  return s:Path.unixpath(relpath)
endfunction

function! hita#get_meta(name, ...) abort
  " WARNING:
  " DO NOT USE 'hita' instance in this method.
  let expr = get(a:000, 1, '%')
  let meta = s:get_meta_instance(bufnr(expr))
  return get(meta, a:name, get(a:000, 0, ''))
endfunction
function! hita#set_meta(name, value, ...) abort
  " WARNING:
  " DO NOT USE 'hita' instance in this method.
  let expr = get(a:000, 0, '%')
  let meta = s:get_meta_instance(bufnr(expr))
  let meta[a:name] = a:value
endfunction
function! hita#expand(expr) abort
  " WARNING:
  " DO NOT USE 'hita' instance in this method.
  if empty(a:expr)
    return ''
  endif
  let bufnum = bufnr(a:expr)
  let meta_filename = hita#get_meta('filename', '', bufnum)
  let real_filename = expand(a:expr)
  let filename = empty(meta_filename) ? real_filename : meta_filename
  " NOTE:
  " Always return a real absolute path
  return s:Path.abspath(s:Path.realpath(filename))
endfunction

function! hita#vital() abort
  return s:V
endfunction
function! hita#throw(msg) abort
  throw printf('vim-hita: %s', a:msg)
endfunction
function! hita#define_variables(prefix, defaults) abort
  " Note:
  "   Funcref is not supported while the variable must start with a capital
  let prefix = empty(a:prefix)
        \ ? 'g:hita'
        \ : printf('g:hita#%s', a:prefix)
  for [key, value] in items(a:defaults)
    let name = printf('%s#%s', prefix, key)
    if !exists(name)
      silent execute printf('let %s = %s', name, string(value))
    endif
    unlet value
  endfor
endfunction

call hita#define_variables('', {
      \ 'test': 0,
      \ 'debug': 0,
      \ 'develop': 1,
      \ 'complete_threshold': 100,
      \})
