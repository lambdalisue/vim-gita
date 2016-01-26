function! s:on_SourceCmd(info) abort
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
function! s:on_BufReadCmd(info) abort
  let content_type = get(a:info, 'content_type')
  if content_type ==# 'show'
    call hita#command#show#edit({
          \ 'commit': a:info.commit,
          \ 'filename': a:info.filename,
          \ 'force': v:cmdbang,
          \})
  elseif content_type ==# 'diff'
    call hita#command#diff#edit({
          \ 'commit': a:info.commit,
          \ 'filenames': empty(a:info.filename) ? [] : [a:info.filename],
          \ 'cached': index(a:info.extra_options, 'cached') >= 0,
          \ 'reverse': index(a:info.extra_options, 'reverse') >= 0,
          \ 'force': v:cmdbang,
          \})
  else
    call hita#throw(printf(
          \ 'Unknown content-type "%s" is specified', content_type,
          \))
  endif
endfunction
function! s:on_FileReadCmd(info) abort
  let content_type = get(a:info, 'content_type')
  if content_type ==# 'show'
    call hita#command#show#read({
          \ 'commit': a:info.commit,
          \ 'filename': a:info.filename,
          \ 'force': v:cmdbang,
          \})
  elseif content_type ==# 'diff'
    call hita#command#diff#read({
          \ 'commit': a:info.commit,
          \ 'filenames': empty(a:info.filename) ? [] : [a:info.filename],
          \ 'cached': index(a:info.extra_options, 'cached') >= 0,
          \ 'reverse': index(a:info.extra_options, 'reverse') >= 0,
          \ 'force': v:cmdbang,
          \})
  else
    call hita#throw(printf(
          \ 'Unknown content-type "%s" is specified', content_type,
          \))
  endif
endfunction

function! hita#autocmd#call(name) abort
  let fname = 's:on_' . a:name
  if !exists('*' . fname)
    call hita#throw(printf(
          \ 'No autocmd function "%s" is found.', fname
          \))
  endif
  try
    let result = hita#autocmd#parse_filename(expand('<afile>'))
    let [commit, filename] = hita#variable#split_treeish(result.treeish)
    let result.commit = commit
    let result.filename = filename
    let result.extra_options = split(result.extra_option, ':')
    call call(fname, [result])
  catch /^vim-hita/
    call hita#util#handle_exception(v:exception)
  endtry
endfunction
function! hita#autocmd#bufname(hita, options) abort
  let options = extend({
        \ 'content_type': 'show',
        \ 'extra_options': [],
        \ 'treeish': '',
        \}, a:options)
  let meta = a:hita.git.get_meta()
  let bits = [
        \ meta.local.name,
        \ options.content_type ==# 'show' ? '' : options.content_type,
        \ join(filter(options.extra_options, '!empty(v:val)'), ':'),
        \]
  let domain = join(filter(bits, '!empty(v:val)'), ':')
  return printf('hita://%s/%s', domain, options.treeish)
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
let s:schemes = [
      \ ['^hita://\([^/:]\{-}\):\([^/:]\{-}\):\([^/]\{-}\)/\(.\+\)$', {
      \   'repository': 1,
      \   'content_type': 2,
      \   'extra_option': 3,
      \   'treeish': 4,
      \ }],
      \ ['^hita://\([^/:]\{-}\):\([^/:]\{-}\)/\(.\+\)$', {
      \   'repository': 1,
      \   'content_type': 2,
      \   'extra_option': '',
      \   'treeish': 3,
      \ }],
      \ ['^hita://\([^/:]\{-}\)/\(.\+\)$', {
      \   'repository': 1,
      \   'content_type': 'show',
      \   'extra_option': '',
      \   'treeish': 2,
      \ }],
      \]
function! hita#autocmd#parse_filename(filename) abort
  for scheme in s:schemes
    if a:filename !~# scheme[0]
      continue
    endif
    let m = matchlist(a:filename, scheme[0])
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
  call hita#throw(printf(
        \ '"%s" does not have required component(s).',
        \ a:filename
        \))
endfunction
