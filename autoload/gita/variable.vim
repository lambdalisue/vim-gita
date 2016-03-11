let s:V = gita#vital()
let s:Path = s:V.import('System.Filepath')
let s:Prompt = s:V.import('Vim.Prompt')
let s:Guard = s:V.import('Vim.Guard')
let s:GitTerm = s:V.import('Git.Term')

function! s:validate_filename(filename, ...) abort
  if empty(a:filename)
    call gita#throw(
          \ 'ValidationError: A filename cannot be empty'
          \)
  endif
  if s:Path.is_relative(a:filename)
    call gita#throw(printf(
          \ 'A filename "%s" requires to be a real absolute path before validation',
          \ a:filename,
          \))
  endif
endfunction

function! gita#variable#get_valid_commit(commit, ...) abort
  let options = extend({
        \ '_allow_empty': 0,
        \}, get(a:000, 0, {}))
  if empty(a:commit) && !options._allow_empty
    let guard = s:Guard.store(['_complete_options', s:])
    let s:_complete_options = options
    try
      call histadd('input', 'origin/HEAD')
      let commit = s:Prompt.ask(
            \ 'Please input a commit: ', '',
            \ 'customlist,gita#complete#commit',
            \)
      if empty(commit)
        call gita#throw('Cancel')
      endif
    finally
      call guard.restore()
    endtry
  else
    let commit = a:commit
  endif
  call s:GitTerm.validate_commit(commit, options)
  return commit
endfunction

function! gita#variable#get_valid_commitish(commitish, ...) abort
  let options = extend({
        \ '_allow_empty': 0,
        \}, get(a:000, 0, {}))
  if empty(a:commitish) && !options._allow_empty
    let guard = s:Guard.store(['_complete_options', s:])
    let s:_complete_options = options
    try
      call histadd('input', 'origin/HEAD')
      let commitish = s:Prompt.ask(
            \ 'Please input a commitish: ', '',
            \ 'customlist,gita#complete#commit',
            \)
      if empty(commitish)
        call gita#throw('Cancel')
      endif
    finally
      call guard.restore()
    endtry
  else
    let commitish = a:commitish
  endif
  call s:GitTerm.validate_commitish(commitish, options)
  return commitish
endfunction

function! gita#variable#get_valid_treeish(treeish, ...) abort
  let options = extend({
        \ '_allow_empty': 0,
        \}, get(a:000, 0, {}))
  if empty(a:treeish) && !options._allow_empty
    let guard = s:Guard.store(['_complete_options', s:])
    let s:_complete_options = options
    try
      call histadd('input', 'origin/HEAD')
      let treeish = s:Prompt.ask(
            \ 'Please input a treeish: ', '',
            \ 'customlist,gita#complete#commit',
            \)
      if empty(treeish)
        call gita#throw('Cancel')
      endif
    finally
      call guard.restore()
    endtry
  else
    let treeish = a:treeish
  endif
  call s:GitTerm.validate_treeish(treeish, options)
  return treeish
endfunction

function! gita#variable#get_valid_range(range, ...) abort
  let options = extend({
        \ '_allow_empty': 0,
        \}, get(a:000, 0, {}))
  if empty(a:range) && !options._allow_empty
    let guard = s:Guard.store(['_complete_options', s:])
    let s:_complete_options = options
    try
      call histadd('input', 'origin/HEAD...')
      let range = s:Prompt.ask(
            \ 'Please input a commitish or commitish range: ', '',
            \ 'customlist,gita#complete#commit',
            \)
      if empty(range)
        call gita#throw('Cancel')
      endif
    finally
      call guard.restore()
    endtry
  else
    let range = a:range
  endif
  call s:GitTerm.validate_range(range, options)
  return range
endfunction

function! gita#variable#get_valid_filename(filename, ...) abort
  let options = get(a:000, 0, {})
  if empty(a:filename)
    let guard = s:Guard.store(['_complete_options', s:])
    let s:_complete_options = options
    try
      call histadd('input', s:Path.relpath(gita#meta#expand('%')))
      let filename = s:Prompt.ask(
            \ 'Please input a filename: ', '',
            \ 'customlist,gita#complete#filename'
            \)
      if empty(filename)
        call gita#throw('Cancel')
      endif
    finally
      call guard.restore()
    endtry
  else
    let filename = gita#meta#expand(a:filename)
  endif
  " NOTE:
  " Alwasy return a real absolute path
  let filename = s:Path.abspath(s:Path.realpath(filename))
  call s:validate_filename(filename, options)
  return filename
endfunction
