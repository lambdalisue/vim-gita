let s:V = vital#of('vim_gita')
let s:Prelude = s:V.import('Prelude')
let s:Path = s:V.import('System.Filepath')
let s:Compat = s:V.import('Vim.Compat')
let s:Prompt = s:V.import('Vim.Prompt')
let s:MemoryCache = s:V.import('System.Cache.Memory')
let s:Git = s:V.import('Git')
let s:GitProcess = s:V.import('Git.Process')

function! s:is_expired(expr) abort
  let cbufname = hita#get_meta('bufname')
  let ccwd = hita#get_meta('cwd')
  let bufnum = bufnr(a:expr)
  let bufname = bufname(bufnum)
  let buftype = s:Compat.getbufvar(bufnum, '&buftype')
  let filetype = s:Compat.getbufvar(bufnum, '&filetype')
  if filetype =~# '^\%(hita-status\|hita-commit\)$'
    " hita-status/hita-commit cascade git instance so do not expired
    return 0
  elseif buftype =~# '^\%(\|nowrite\|acwrite\)$' && bufname !=# cbufname
    " filename has changed on file like buffer
    return 1
  elseif buftype=~# '^\%(nofile\|quickfix\|help\)$' && getcwd() !=# ccwd
    " current working directory has changed on non file buffer
    return 1
  endif
  return 0
endfunction
function! s:get_git_instance(bufnum) abort
  let bufname = bufname(a:bufnum)
  let buftype = s:Compat.getbufvar(a:bufnum, '&buftype')
  let repository_cache = s:get_repository_cache()
  if bufname =~# '^hita://' || bufname =~# '^hita:.\+'
    " git buffer
    let repository_name = matchstr(
          \ bufname, '^hita:\%(//\)\?\zs[^:/]\+\ze'
          \)
    let git = repository_cache.get(repository_name, {})
    let git = empty(git) ? s:Git.get(getcwd()) : git
  elseif buftype =~# '^\%(\|nowrite\|acwrite\)$'
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
  if bufexists(a:bufnum)
    call setbufvar(a:bufnum, '_git', git)
    call hita#set_meta('bufname', bufname(a:bufnum))
    call hita#set_meta('cwd', getcwd())
  endif
  return git
endfunction
function! s:get_meta_instance(bufnum) abort
  let meta = s:Compat.getbufvar(a:bufnum, '_hita_meta', {})
  if bufexists(a:bufnum)
    call setbufvar(a:bufnum, '_hita_meta', meta)
  endif
  return meta
endfunction
function! s:get_repository_cache() abort
  if !exists('s:repository_cache')
    let s:repository_cache = s:MemoryCache.new()
  endif
  return s:repository_cache
endfunction

function! s:is_debug() abort
  return g:hita#debug
endfunction
function! s:is_batch() abort
  return g:hita#test
endfunction

function! hita#get(...) abort
  let expr = get(a:000, 0, '%')
  let options = get(a:000, 1, {
        \ 'force': 0,
        \})
  let bufnum = bufnr(expr)
  let git = s:Compat.getbufvar(bufnum, '_git', {})
  if !options.force && !empty(git) && !s:is_expired(bufnum)
    return git
  endif
  return s:get_git_instance(bufnum)
endfunction
function! hita#get_or_fail(...) abort
  let expr = get(a:000, 0, '%')
  let git = hita#get(expr)
  if git.is_enabled
    return git
  endif
  call hita#throw(printf(
        \ 'Attention: vim-hita is not available on %s', expand(expr),
        \))
endfunction
function! hita#clear() abort
  let repository_cache = s:get_repository_cache()
  call repository_cache.clear()
  call s:Git.clear()
  bufdo silent unlet! b:_git
endfunction

function! hita#execute(git, name, ...) abort
  let options = get(a:000, 0, {})
  let config  = get(a:000, 1, {})
  if !g:hita#debug
    return s:GitProcess.execute(a:git, a:name, options, config)
  else
    let result = s:GitProcess.execute(a:git, a:name, options, config)
    call s:Prompt.debug(printf(
          \ 'o %s: %s', (result.status ? 'Fail' : 'OK'), join(result.args),
          \))
    if g:hita#debug >= 2
      call s:Prompt.debug(printf(
            \ '| status: %d', result.status,
            \))
      call s:Prompt.debug('| --- content ---')
      for line in result.content
        call s:Prompt.debug(line)
      endfor
      call s:Prompt.debug('| ----- end -----')
    endif
    call s:Prompt.debug('')
    return result
  endif
endfunction
function! hita#get_relative_path(git, path) abort
  " NOTE:
  " Return a unix relative path from the repository for git command.
  " The {path} requires to be a (real) absolute paht.
  if empty(a:path)
    return ''
  endif
  let relpath = s:Git.get_relative_path(a:git, a:path)
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
function! hita#remove_meta(name, ...) abort
  " WARNING:
  " DO NOT USE 'hita' instance in this method.
  let expr = get(a:000, 0, '%')
  let meta = s:get_meta_instance(bufnr(expr))
  if has_key(meta, a:name)
    unlet meta[a:name]
  endif
endfunction

function! hita#is_enabled(...) abort
  return call('hita#get', a:000).is_enabled
endfunction
function! hita#vital() abort
  return s:V
endfunction
function! hita#expand(expr) abort
  " WARNING:
  " DO NOT USE 'hita' instance in this method.
  if empty(a:expr)
    return ''
  endif
  let bufnum = bufnr(a:expr)
  let meta_filename = hita#get_meta('filename', '', bufnum)
  let real_filename = expand(
        \ s:Prelude.is_string(a:expr) ? a:expr : bufname(a:expr)
        \)
  let filename = empty(meta_filename) ? real_filename : meta_filename
  " NOTE:
  " Always return a real absolute path
  return s:Path.abspath(s:Path.realpath(filename))
endfunction
function! hita#throw(...) abort
  let msg = join(a:000)
  throw printf('vim-hita: %s', msg)
endfunction

call s:Prompt.set_config({
      \ 'debug': function('s:is_debug'),
      \ 'batch': function('s:is_batch'),
      \})
call hita#util#define_variables('', {
      \ 'test': 0,
      \ 'debug': 0,
      \ 'develop': 1,
      \ 'complete_threshold': 100,
      \})
