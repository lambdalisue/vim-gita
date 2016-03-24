let s:V = gita#vital()
let s:Path = s:V.import('System.Filepath')
let s:Git = s:V.import('Git')

function! gita#autocmd#bufname(options) abort
  let options = extend({
        \ 'nofile': 0,
        \ 'content_type': 'show',
        \ 'extra_option': [],
        \ 'commitish': '',
        \ 'path': '',
        \}, a:options)
  let git = gita#core#get_or_fail()
  let refinfo = gita#core#get_refinfo()
  let refname = empty(get(refinfo, 'refname'))
        \ ? git.repository_name
        \ : refinfo.refname
  let realpath = s:Path.realpath(options.path)
  let unixpath = s:Path.unixpath(
        \ s:Path.is_absolute(realpath)
        \   ? s:Git.get_relative_path(git, realpath)
        \   : realpath
        \)
  let treeish = printf('%s:%s', options.commitish, unixpath)
  let bits = [
        \ refname,
        \ options.content_type ==# 'show' && empty(options.extra_option)
        \   ? ''
        \   : options.content_type,
        \ join(filter(options.extra_option, '!empty(v:val)'), ':'),
        \]
  let domain = join(filter(bits, '!empty(v:val)'), ':')
  if options.nofile
    if !empty(options.commitish) || !empty(options.path)
      call gita#throw(printf(
            \ 'A buffer name for %s is specified as "nofile" but options contains "commitish" or "path"',
            \ options.content_type,
            \))
    endif
    let bufname = printf('gita:%s', domain)
  else
    let bufname = printf('gita://%s/%s', domain, treeish)
  endif
  " NOTE:
  " Windows does not allow a buffer name which ends with : so remove trailings
  let bufname = substitute(bufname, ':\+$', '', '')
  return bufname
endfunction

function! gita#autocmd#call(name) abort
  try
    let content_type = gita#autocmd#parse_bufname(expand('<afile>'))[1]
    if content_type =~# '^\%(branch\|show\|diff\)$'
      return gita#content#autocmd(a:name)
    endif
    let fname = printf(
          \ 'gita#ui#%s#autocmd',
          \ substitute(content_type, '-', '_', 'g'),
          \)
    call call(fname, [a:name])
  catch /^\%(vital: Git[:.]\|vim-gita:\)/
    call gita#util#handle_exception()
  endtry
endfunction

function! gita#autocmd#parse_cmdarg(...) abort
  let cmdarg = get(a:000, 0, v:cmdarg)
  let options = {}
  if cmdarg =~# '++enc='
    let options.encoding = matchstr(cmdarg, '++enc=\zs[^ ]\+\ze')
  endif
  if cmdarg =~# '++ff='
    let options.fileformat = matchstr(cmdarg, '++ff=\zs[^ ]\+\ze')
  endif
  if cmdarg =~# '++bad='
    let options.bad = matchstr(cmdarg, '++bad=\zs[^ ]\+\ze')
  endif
  if cmdarg =~# '++bin'
    let options.binary = 1
  endif
  if cmdarg =~# '++nobin'
    let options.nobinary = 1
  endif
  if cmdarg =~# '++edit'
    let options.edit = 1
  endif
  return options
endfunction

function! gita#autocmd#parse_bufname(bufname) abort
  let m = matchlist(
        \ a:bufname,
        \ '^gita:\%(//\)\?\([^:\\/]\+\)\%(:\([^:\\/]\+\)\)\?'
        \)
  if empty(m)
    call gita#throw(printf(
          \ 'A buffer name %s does not contain required components',
          \ a:bufname,
          \))
  endif
  let refname = m[1]
  let content_type = empty(m[2]) ? 'show' : m[2]
  return [refname, content_type]
endfunction
