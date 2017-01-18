let s:V = gita#vital()
let s:Dict = s:V.import('Data.Dict')
let s:Console = s:V.import('Vim.Console')

function! gita#content#build_bufname(content_type, options) abort
  let options = extend({
        \ 'nofile': 0,
        \ 'extra_options': [],
        \ 'treeish': '',
        \}, a:options)
  if g:gita#develop
    if options.nofile && !empty(options.treeish)
      call gita#throw(printf(
            \ 'A buffer name for "%s" is "nofile" but "treeish" is specified.',
            \ a:content_type,
            \))
    endif
  endif
  let git = gita#core#get_or_fail()
  let refinfo = gita#core#get_refinfo()
  let refname = empty(get(refinfo, 'refname'))
        \ ? git.repository_name
        \ : refinfo.refname
  let bits = [
        \ refname,
        \ a:content_type,
        \ join(filter(options.extra_options, '!empty(v:val)'), ':'),
        \]
  let prefix = options.nofile ? 'gita:' : 'gita://'
  let suffix = options.nofile ? '' : '/' . options.treeish
  let bufname = prefix . join(filter(bits, '!empty(v:val)'), ':') . suffix
  " NOTE:
  " Windows does not allow a buffer name which ends with : so remove trailings
  let bufname = substitute(bufname, ':\+$', '', '')
  return bufname
endfunction

function! gita#content#parse_bufname(bufname) abort
  if a:bufname =~# '^gita://'
    let m = matchlist(
          \ a:bufname,
          \ '^gita://\([^:/]\+\):\([^:/]*\):\?\([^/]*\)/\(.*\)$'
          \)
    if empty(m)
      call gita#throw(printf(
            \ 'A buffer name "%s" does not follow "%s" pattern',
            \ a:bufname, 'gita://<refname>:<content_type>[:<extra_options>]/<treeish>',
            \))
    endif
    return {
          \ 'bufname': a:bufname,
          \ 'nofile': 0,
          \ 'refname': m[1],
          \ 'content_type': m[2],
          \ 'extra_options': split(m[3], ':'),
          \ 'treeish': m[4],
          \}
  elseif a:bufname =~# '^gita:'
    let m = matchlist(
          \ a:bufname,
          \ '^gita:\([^:/]\+\):\([^:/]\+\):\?\(.*\)$'
          \)
    if empty(m)
      call gita#throw(printf(
            \ 'A buffer name "%s" does not follow "%s" pattern',
            \ a:bufname, 'gita://<refname>:<content_type>[:<extra_options>]',
            \))
    endif
    return {
          \ 'bufname': a:bufname,
          \ 'nofile': 1,
          \ 'refname': m[1],
          \ 'content_type': m[2],
          \ 'extra_options': split(m[3], ':'),
          \}
  else
    call gita#throw(printf(
          \ 'A buffer name "%s" does not follow a correct gita buffer name pattern',
          \ a:bufname,
          \))
  endif
endfunction

function! gita#content#autocmd(name) abort
  try
    let bufinfo = gita#content#parse_bufname(expand('<afile>'))
    let funcname = printf(
          \ 'gita#content#%s#autocmd',
          \ substitute(bufinfo.content_type, '-', '_', 'g'),
          \)
    call call(funcname, [a:name, bufinfo])
  catch /^Vim\%((\a\+)\)\=:E117/
    call s:Console.warn(printf(
          \ 'gita: "%s" in "%s" is not supported',
          \ a:name, expand('<afile>'),
          \))
    call s:Console.debug(v:exception)
  catch /^\%(vital: Git[:.]\|gita:\)/
    call gita#util#handle_exception()
  endtry
endfunction
