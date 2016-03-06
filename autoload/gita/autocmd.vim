let s:V = gita#vital()
let s:Path = s:V.import('System.Filepath')
let s:Git = s:V.import('Git')

function! s:parse_cmdarg(cmdarg) abort
  let options = {}
  if a:cmdarg =~# '++enc='
    let options.encoding = matchstr(a:cmdarg, '++enc=\zs[^ ]\+\ze')
  endif
  if a:cmdarg =~# '++ff='
    let options.fileformat = matchstr(a:cmdarg, '++ff=\zs[^ ]\+\ze')
  endif
  if a:cmdarg =~# '++bad='
    let options.bad = matchstr(a:cmdarg, '++bad=\zs[^ ]\+\ze')
  endif
  if a:cmdarg =~# '++bin'
    let options.binary = 1
  endif
  if a:cmdarg =~# '++nobin'
    let options.nobinary = 1
  endif
  if a:cmdarg =~# '++edit'
    let options.edit = 1
  endif
  return options
endfunction

function! s:parse_bufname(bufname) abort
  let options = {}
  for scheme in s:schemes
    let options = gita#util#matchdict(a:bufname, scheme[0], scheme[1])
    if !empty(options)
      break
    endif
  endfor
  if empty(options)
    call gita#throw(printf(
          \ 'A bufname %s does not have required components',
          \ a:bufname,
          \))
  endif
  return options
endfunction


function! gita#autocmd#bufname(options, ...) abort
  let options = extend({
        \ 'nofile': 0,
        \ 'refname': '',
        \ 'content_type': 'show',
        \ 'extra_option': [],
        \ 'commitish': '',
        \ 'path': '',
        \}, a:options)
  let git = call('gita#core#get_or_fail', a:000)
  let refname = empty(options.refname)
        \ ? git.repository_name
        \ : options.refname
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
    let info = s:parse_bufname(expand('<afile>'))
    let info.cascade = get(g:, 'gita#autocmd#_cascade', {})
    let fname = printf(
          \ 'gita#command#ui#%s#autocmd',
          \ substitute(info.content_type, '-', '_', 'g'),
          \)
    call call(fname, [a:name, info])
  catch /^\%(vital: Git[:.]\|vim-gita:\)/
    call gita#util#handle_exception()
  finally
    silent! unlet! g:gita#autocmd#_cascade
  endtry
endfunction

function! gita#autocmd#cascade(options) abort
  let g:gita#autocmd#_cascade = a:options
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

" gita://<refname>:<content-type>
" gita://<refname>:<content-type>/<extra-attribute>
" gita://<refname>:<content-type>:<extra-attribute>
" gita:<refname>:<content-type>
" gita:<refname>:<content-type>/<extra-attribute>
" gita:<refname>:<content-type>:<extra-attribute>
let s:schemes = [
      \ ['^gita://\([^/:]\+\):\([^/:]\+\)\%([/:]\(.*\)\)\?$', {
      \   'refname': 1,
      \   'content_type': 2,
      \   'extra_attribute': 3,
      \ }],
      \ ['^gita:\([^/:]\+\):\([^/:]\+\)\%([/:]\(.*\)\)\?$', {
      \   'refname': 1,
      \   'content_type': 2,
      \   'extra_attribute': 3,
      \ }],
      \]
