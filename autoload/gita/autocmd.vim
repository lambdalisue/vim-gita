let s:V = gita#vital()
let s:Prelude = s:V.import('Prelude')
let s:Path = s:V.import('System.Filepath')
let s:Git = s:V.import('Git')
let s:GitTerm = s:V.import('Git.Term')

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
  let options.binary = a:cmdarg =~# '++bin'
  let options.nobinary = a:cmdarg =~# '++nobin'
  let options.edit = a:cmdarg =~# '++edit'
  return options
endfunction

function! s:parse_bufname(bufname) abort
  let options = {}
  let result = s:parse_filename(expand(a:expr))
  if empty(result.treeish)
    let commit = ''
    let unixpath = ''
  else
    let [commit, unixpath] = s:GitTerm.split_treeish(result.treeish, {
          \ '_allow_range': 1,
          \})
    let options.comit = commit
    " NOTE:
    " filename is always a relative path from the repository root so convert
    " it to a real absolute path (s:Git.get_absolute_path returns a real path)
    if !empty(unixpath)
      let git = gita#core#get_or_fail()
      let options.filename = s:Git.get_absolute_path(git, unixpath)
    endif
  endif
  for extra_option in split(result.extra_option, ':')
    let options[extra_option] = 1
  endfor
  return options
endfunction

function! s:on_SourceCmd() abort
  let content = getbufline(expand('<afile>'), 1, '$')
  try
    let tempfile = tempname()
    call writefile(content, tempfile)
    execute printf('source %s', fnameescape(tempfile))
  finally
    if filereadable(tempfile)
      call delete(tempfile)
    endif
  endtry
endfunction

function! s:on_BufReadCmd() abort
  call gita#util#doautocmd('BufReadPre')
  let options = {
        \ 'encoding': '',
        \ 'fileformat': '',
        \ 'bad': '',
        \}
  let options = extend(options, get(g:, 'gita#var', {}))
  let options = extend(options, s:parse_bufname(expand('<afile>')))
  let options = extend(options, s:parse_cmdarg(v:cmdarg))
  let content_type = substitute(get(info, 'content_type'), '-', '_', 'g')
  call call(
        \ printf('gita#command#ui#%s#BufReadCmd', content_type),
        \ [options],
        \)
  call gita#util#doautocmd('BufReadPost')
endfunction

function! s:on_FileReadCmd() abort
  call gita#util#doautocmd('FileReadPre')
  let info = gita#autocmd#parse(expand('<afile>'))
  let options = {
        \ 'encoding': '',
        \ 'fileformat': '',
        \ 'bad': '',
        \}
  let options = extend(options, get(g:, 'gita#var', {}))
  let options = extend(options, s:parse_cmdarg(v:cmdarg))
  let options = extend(options, info.extra_options)
  let content_type = substitute(get(info, 'content_type'), '-', '_', 'g')
  call call(
        \ printf('gita#command#ui#%s#FileReadCmd', content_type),
        \ [options],
        \)
  call gita#util#doautocmd('FileReadPost')
endfunction

function! s:on_BufWriteCmd() abort
  call gita#util#doautocmd('BufWritePre')
  let info = gita#autocmd#parse(expand('<afile>'))
  let options = {
        \ 'encoding': '',
        \ 'fileformat': '',
        \ 'bad': '',
        \}
  let options = extend(options, get(g:, 'gita#var', {}))
  let options = extend(options, s:parse_cmdarg(v:cmdarg))
  let options = extend(options, info.extra_options)
  let content_type = substitute(get(info, 'content_type'), '-', '_', 'g')
  call call(
        \ printf('gita#command#ui#%s#BufWriteCmd', content_type),
        \ [options],
        \)
  call gita#util#doautocmd('BufWritePost')
endfunction

function! s:on_FileWriteCmd() abort
  call gita#util#doautocmd('FileWritePre')
  let info = gita#autocmd#parse(expand('<afile>'))
  let options = {
        \ 'encoding': '',
        \ 'fileformat': '',
        \ 'bad': '',
        \}
  let options = extend(options, get(g:, 'gita#var', {}))
  let options = extend(options, s:parse_cmdarg(v:cmdarg))
  let options = extend(options, info.extra_options)
  let content_type = substitute(get(info, 'content_type'), '-', '_', 'g')
  call call(
        \ printf('gita#command#ui#%s#FileWriteCmd', content_type),
        \ [options],
        \)
  call gita#util#doautocmd('FileWritePost')
endfunction

function! s:on_BufWritePre() abort
  let b:_gita_autocmd_modified = &modified
endfunction

function! s:on_BufWritePost() abort
  if get(b:, '_gita_autocmd_modified', &modified) != &modified
    if gita#core#get().is_enabled
      call gita#util#doautocmd('User', 'GitaStatusModified')
    endif
  endif
  silent! unlet! b:_gita_autocmd_modified
endfunction

function! s:on_GitaStatusModified() abort
  let pattern = '^\%(gita-status\|gita-commit\|gita-diff-ls\)$'
  let winnum = winnr()
  keepjump windo if &filetype =~# pattern | edit | endif
  execute printf('keepjump %dwincmd w', winnum)
endfunction

function! gita#autocmd#call(name) abort
  let fname = 's:on_' . a:name
  if !exists('*' . fname)
    call gita#throw(printf(
          \ 'No autocmd function "%s" is found.', fname
          \))
  endif
  try
    call call(fname, [])
  catch /^\%(vital: Git[:.]\|vim-gita:\)/
    call gita#util#handle_exception()
  endtry
endfunction

function! gita#autocmd#parse(expr) abort
  let git = gita#core#get_or_fail(a:expr)
  let result = s:parse_filename(expand(a:expr))
  let [commit, unixpath] = s:GitTerm.split_treeish(result.treeish, {
        \ '_allow_range': 1,
        \})
  let result.commit = commit
  " NOTE:
  " filename is always a relative path from the repository root so convert
  " it to a real absolute path (s:Git.get_absolute_path returns a real path)
  let result.filename = empty(unixpath)
        \ ? ''
        \ : s:Git.get_absolute_path(git, unixpath)
  let result.extra_options = {}
  for extra_option in split(result.extra_option, ':')
    let result.extra_options[extra_option] = 1
  endfor
  return result
endfunction

function! gita#autocmd#bufname(git, options) abort
  let options = extend({
        \ 'filebase': 1,
        \ 'content_type': 'show',
        \ 'extra_options': [],
        \ 'commitish': '',
        \ 'path': '',
        \}, a:options)
  let realpath = s:Path.realpath(options.path)
  let unixpath = s:Path.unixpath(
        \ s:Path.is_absolute(realpath)
        \   ? s:Git.get_relative_path(a:git, realpath)
        \   : realpath
        \)
  let treeish = printf('%s:%s', options.commitish, unixpath)
  let bits = [
        \ a:git.repository_name,
        \ options.content_type ==# 'show' && empty(options.extra_options)
        \   ? ''
        \   : options.content_type,
        \ join(filter(options.extra_options, '!empty(v:val)'), ':'),
        \]
  let domain = join(filter(bits, '!empty(v:val)'), ':')
  if options.filebase
    let bufname = printf('gita://%s/%s', domain, treeish)
  else
    let bufname = printf('gita:%s:%s', domain, treeish)
  endif
  " NOTE:
  " Windows does not allow a buffer name which ends with : so remove trailings
  let bufname = substitute(bufname, ':\+$', '', '')
  return bufname
endfunction

" gita://<refname>/<treeish>
" gita://<refname>:<content-type>/<treeish>
" gita://<refname>:<content-type>:<extra-option>/<treeish>
" gita://vim-gita/:                             git show
" gita://vim-gita/HEAD~:                        git show HEAD~
" gita://vim-gita/:README.md                    git show :README.md
" gita://vim-gita/develop:README.md             git show develop:README.md
" gita://vim-gita:diff/                         git diff
" gita://vim-gita:diff/:README.md               git diff -- README.md
" gita://vim-gita:diff/HEAD:README.md           git diff HEAD -- README.md
" gita://vim-gita:diff:cached/                  git diff --cached
" gita://vim-gita:diff:cached/:README.md        git diff --cached -- README.md
" gita://vim-gita:diff:cached/HEAD:README.md    git diff --cached HEAD -- README.md
" gita://vim-gita:diff:cached:reverse/HEAD:README.md    git diff --cached --reverse HEAD -- README.md
" gita:<refname>:<content-type>
" gita:<refname>:<content-type>:<extra-option>
" gita:<refname>:<content-type>:<extra-option>:<treeish>
function! s:parse_filename(filename) abort
  let ncolons = len(substitute(a:filename, '[^:]', '', 'g'))
  let filename = len(ncolons) < 3
        \ ? a:filename . repeat(':', 3 - ncolons)
        \ : a:filename
  for scheme in s:schemes
    if filename !~# scheme[0]
      continue
    endif
    let m = matchlist(filename, scheme[0])
    let o = {}
    for [key, value] in items(scheme[1])
      if type(value) == type(0)
        let o[key] = m[value]
      else
        let o[key] = value
      endif
      unlet value
    endfor
    return o
  endfor
  call gita#throw(printf(
        \ '"%s" does not have required component(s).',
        \ a:filename
        \))
endfunction

let s:schemes = [
      \ ['^gita://\([^/:]\{-}\):\([^/:]\{-}\):\([^/]\{-}\)/\(.\+\)$', {
      \   'repository': 1,
      \   'content_type': 2,
      \   'extra_option': 3,
      \   'treeish': 4,
      \ }],
      \ ['^gita://\([^/:]\{-}\):\([^/:]\{-}\)/\(.\+\)$', {
      \   'repository': 1,
      \   'content_type': 2,
      \   'extra_option': '',
      \   'treeish': 3,
      \ }],
      \ ['^gita://\([^/:]\{-}\)/\(.\+\)$', {
      \   'repository': 1,
      \   'content_type': 'show',
      \   'extra_option': '',
      \   'treeish': 2,
      \ }],
      \ ['^gita://\([^/:]\{-}\):\([^/:]\{-}\):\([^/]\{-}\):\(.*\)$', {
      \   'repository': 1,
      \   'content_type': 2,
      \   'extra_option': 3,
      \   'treeish': 4,
      \ }],
      \ ['^gita:\([^/:]\{-}\):\([^/:]\{-}\):\(.*\)$', {
      \   'repository': 1,
      \   'content_type': 2,
      \   'extra_option': '',
      \   'treeish': 3,
      \ }],
      \]
