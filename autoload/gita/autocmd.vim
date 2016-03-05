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
  let info = gita#autocmd#parse(expand('<afile>'))
  let options = {
        \ 'encoding': '',
        \ 'fileformat': '',
        \ 'bad': '',
        \}
  let options = extend(options, get(g:, 'gita#var', {}))
  let options = extend(options, s:parse_cmdarg(v:cmdarg))
  let options = extend(options, info.extra_options)
  let content_type = get(info, 'content_type')
  if content_type ==# 'show'
    call gita#command#show#BufReadCmd({
          \ 'commit': info.commit,
          \ 'filename': info.filename,
          \ 'encoding': options.encoding,
          \ 'fileformat': options.fileformat,
          \ 'bad': options.bad,
          \ 'patch': get(options, 'patch'),
          \})
  elseif content_type ==# 'diff'
    call gita#command#diff#edit({
          \ 'commit': info.commit,
          \ 'filename': info.filename,
          \ 'encoding': options.encoding,
          \ 'fileformat': options.fileformat,
          \ 'bad': options.bad,
          \ 'patch': get(options, 'patch'),
          \ 'cached': get(options, 'cached'),
          \ 'reverse': get(options, 'reverse'),
          \})
  else
    call gita#throw(printf(
          \ 'Unknown content-type "%s" is specified', content_type,
          \))
  endif
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
  let content_type = get(info, 'content_type')
  if content_type ==# 'show'
    call gita#command#show#FileReadCmd({
          \ 'commit': info.commit,
          \ 'filename': info.filename,
          \ 'encoding': options.encoding,
          \ 'fileformat': options.fileformat,
          \ 'bad': options.bad,
          \ 'patch': get(options, 'patch'),
          \})
  elseif content_type ==# 'diff'
    call gita#command#diff#read({
          \ 'commit': info.commit,
          \ 'filename': info.filename,
          \ 'encoding': options.encoding,
          \ 'fileformat': options.fileformat,
          \ 'bad': options.bad,
          \ 'patch': get(options, 'patch'),
          \ 'cached': get(options, 'cached'),
          \ 'reverse': get(options, 'reverse'),
          \})
  else
    call gita#throw(printf(
          \ 'Unknown content-type "%s" is specified', content_type,
          \))
  endif
  call gita#util#doautocmd('FileReadPost')
endfunction
function! s:on_BufWritePre() abort
  let b:_gita_autocmd_modified = &modified
endfunction
function! s:on_BufWritePost() abort
  if get(b:, '_gita_autocmd_modified', &modified) != &modified
    if gita#get().is_enabled
      call gita#util#doautocmd('User', 'GitaStatusModified')
    endif
  endif
  silent! unlet! b:_gita_autocmd_modified
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
  let git = gita#get_or_fail(a:expr)
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

" gita://<repository>/<treeish>
" gita://<repository>:<content-type>/<treeish>
" gita://<repository>:<content-type>:<extra-option>/<treeish>
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
      \]
