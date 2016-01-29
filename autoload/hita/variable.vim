let s:V = hita#vital()
let s:Path = s:V.import('System.Filepath')
let s:Guard = s:V.import('Vim.Guard')
let s:GitTerm = s:V.import('Git.Term')
let s:GitInfo = s:V.import('Git.Info')

function! s:validate_filename(filename, ...) abort
  let options = get(a:000, 0, {})
  call hita#util#validate#not_empty(
        \ a:filename,
        \ 'A filename cannot be empty',
        \)
  call hita#util#validate#true(
        \ s:Path.is_absolute(a:filename),
        \ 'A filename requires to be a real absolute path before validation',
        \)
endfunction

function! hita#variable#get_valid_commit(commit, ...) abort
  let options = extend({
        \ '_allow_empty': 0,
        \}, get(a:000, 0, {}))
  if empty(a:commit) && !options._allow_empty
    let guard = s:Guard.store(['_complete_options', s:])
    let s:_complete_options = options
    try
      call histadd('input', 'origin/HEAD')
      let commit = hita#util#prompt#ask(
            \ 'Please input a commit: ', '',
            \ 'customlist,hita#variable#complete_commit',
            \)
      if empty(commit)
        call hita#throw('Cancel')
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
function! hita#variable#get_valid_commitish(commitish, ...) abort
  let options = extend({
        \ '_allow_empty': 0,
        \}, get(a:000, 0, {}))
  if empty(a:commitish) && !options._allow_empty
    let guard = s:Guard.store(['_complete_options', s:])
    let s:_complete_options = options
    try
      call histadd('input', 'origin/HEAD')
      let commitish = hita#util#prompt#ask(
            \ 'Please input a commitish: ', '',
            \ 'customlist,hita#variable#complete_commit',
            \)
      if empty(commitish)
        call hita#throw('Cancel')
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
function! hita#variable#get_valid_treeish(treeish, ...) abort
  let options = extend({
        \ '_allow_empty': 0,
        \}, get(a:000, 0, {}))
  if empty(a:treeish) && !options._allow_empty
    let guard = s:Guard.store(['_complete_options', s:])
    let s:_complete_options = options
    try
      call histadd('input', 'origin/HEAD')
      let treeish = hita#util#prompt#ask(
            \ 'Please input a treeish: ', '',
            \ 'customlist,hita#variable#complete_commit',
            \)
      if empty(treeish)
        call hita#throw('Cancel')
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
function! hita#variable#get_valid_range(range, ...) abort
  let options = extend({
        \ '_allow_empty': 0,
        \}, get(a:000, 0, {}))
  if empty(a:range) && !options._allow_empty
    let guard = s:Guard.store(['_complete_options', s:])
    let s:_complete_options = options
    try
      call histadd('input', 'origin/HEAD...')
      let range = hita#util#prompt#ask(
            \ 'Please input a commitish or commitish range: ', '',
            \ 'customlist,hita#variable#complete_commit',
            \)
      if empty(range)
        call hita#throw('Cancel')
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
function! hita#variable#get_valid_filename(filename, ...) abort
  let options = get(a:000, 0, {})
  if empty(a:filename)
    let guard = s:Guard.store(['_complete_options', s:])
    let s:_complete_options = options
    try
      call histadd('input', s:Path.relpath(hita#expand('%')))
      let filename = hita#util#prompt#ask(
            \ 'Please input a filename: ', '',
            \ 'customlist,hita#variable#complete_filename'
            \)
      if empty(filename)
        call hita#throw('Cancel')
      endif
    finally
      call guard.restore()
    endtry
  else
    let filename = hita#expand(a:filename)
  endif
  " NOTE:
  " Alwasy return a real absolute path
  let filename = s:Path.abspath(s:Path.realpath(filename))
  call s:validate_filename(filename, options)
  return filename
endfunction

function! hita#variable#complete_commit(arglead, cmdline, cursorpos, ...) abort
  let options = get(s:, '_complete_options', {})
  let options = extend(options, get(a:000, 0, {}))
  try
    let hita = hita#get_or_fail()
    let complete_branches = s:GitInfo.get_available_branches(hita, options)
    let complete_tags = s:GitInfo.get_available_tags(hita, options)
    if !empty(a:arglead)
      let complete_commits = s:GitInfo.get_available_commits(hita, options)
      let commits = complete_branches + complete_tags + complete_commits
    else
      let commits = complete_branches + complete_tags
    endif
    return filter(commits, 'v:val =~# "^" . a:arglead')
  catch
    return []
  endtry
endfunction
function! hita#variable#complete_filename(arglead, cmdline, cursorpos, ...) abort
  let options = get(s:, '_complete_options', {})
  let options = extend(options, get(a:000, 0, {}))
  try
    let hita = hita#get_or_fail()
    let filenames = s:GitInfo.get_available_filenames(hita, options)
    " NOTE:
    " Filter filenames exists under the current working directory
    " and return filenames relative from the current working directory
    let pattern = "^" . escape(getcwd(), '^$\.~[]') . s:Path.separator()
    let filenames = map(
          \ filter(filenames, 'v:val =~# pattern'),
          \ 'fnamemodify(v:val, ":.")',
          \)
    return filter(filenames, 'v:val =~# "^" . a:arglead')
  catch
    return []
  endtry
endfunction
