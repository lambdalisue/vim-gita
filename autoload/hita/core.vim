let s:V = hita#vital()
let s:Path = s:V.import('System.Filepath')
let s:Compat = s:V.import('Vim.Compat')
let s:Git = s:V.import('VCS.Git')

function! s:core(expr) abort
  let bufname = bufname(a:expr)
  let filename = hita#core#expand(a:expr)
  if filereadable(filename)
    let git = s:Git.find(filename)
    let git = empty(git)
          \ ? s:Git.find(resolve(filename))
          \ : git
  else
    let git = s:Git.find(getcwd())
  endif
  let hita = extend(deepcopy(s:hita), {
        \ 'enabled': !empty(git),
        \ 'bufname': bufname,
        \ 'bufnum':  bufnr(a:expr),
        \ 'cwd':     getcwd(),
        \ 'git':     git,
        \})
  if bufexists(a:expr)
    call setbufvar(a:expr, '_hita', hita)
  endif
  return hita
endfunction
function! s:meta(expr) abort
  let bufnum = bufnr(a:expr)
  let meta = s:Compat.getbufvar(bufnum, '_hita_meta', {})
  call setbufvar(bufnum, '_hita_meta', meta)
  return meta
endfunction

function! hita#core#get(...) abort
  let expr = get(a:000, 0, '%')
  let hita = s:Compat.getbufvar(expr, '_hita', {})
  if !empty(hita) && !hita.is_expired()
    return hita
  endif
  return s:core(expr)
endfunction
function! hita#core#get_meta(name, ...) abort
  let expr = get(a:000, 1, '%')
  let meta = s:meta(expr)
  return get(meta, a:name, get(a:000, 0, ''))
endfunction
function! hita#core#set_meta(name, value, ...) abort
  let expr = get(a:000, 0, '%')
  let meta = s:meta(expr)
  let meta[a:name] = a:value
endfunction
function! hita#core#expand(expr) abort
  return hita#core#get_meta('filename', expand(a:expr), a:expr)
endfunction

let s:hita = {}
function! s:hita.is_enabled() abort
  return self.enabled
endfunction
function! s:hita.is_expired() abort
  let bufnum = get(self, 'bufnum', -1)
  let bufname = bufname(bufnum)
  let buftype = s:Compat.getbufvar(bufnum, '&buftype')
  if empty(buftype) && bufname !=# self.bufname
    return 1
  elseif (!empty(buftype) || empty(bufname)) && getcwd() !=# self.cwd
    return 1
  else
    return 0
  endif
endfunction
function! s:hita.fail_on_disabled() abort
  if !self.is_enabled()
    call hita#throw('Disabled: Hita is not available on the buffer')
  endif
endfunction
function! s:hita.get_absolute_path(path) abort
  if empty(a:path)
    return ''
  endif
  let path = s:Path.realpath(a:path)
  if self.is_enabled()
    return s:Path.is_relative(path)
          \ ? self.git.get_absolute_path(path)
          \ : path
  else
    return s:Path.abspath(path)
  endif
endfunction
function! s:hita.get_relative_path(path) abort
  if empty(a:path)
    return ''
  endif
  let path = s:Path.realpath(a:path)
  if self.is_enabled()
    return s:Path.is_absolute(path)
          \ ? self.git.get_relative_path(path)
          \ : path
  else
    return s:Path.relpath(path)
  endif
endfunction
function! s:hita.get_repository_name() abort
  return self.is_enabled()
        \ ? fnamemodify(self.git.repository, ':h:t')
        \ : 'not-in-repository'
endfunction
