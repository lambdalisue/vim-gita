let s:V = hita#vital()
let s:Prelude = s:V.import('Prelude')
let s:Dict = s:V.import('Data.Dict')
let s:Path = s:V.import('System.Filepath')
let s:Guard = s:V.import('Vim.Guard')

function! s:throw(msg) abort
  call hita#throw(printf('ValidationError: %s', a:msg))
endfunction

function! s:is_valid_commit(commit, options) abort
  " https://www.kernel.org/pub/software/scm/git/docs/git-check-commit-format.html
  if a:commit =~# '/\.' || a:commit =~# '.lock/' || a:commit =~# '\.lock$'
    return 'no slash-separated component can begin with a dot or end with the sequence .lock'
  elseif a:commit =~# '\.\.'
    return 'no two consective dots .. are allowed'
  elseif a:commit =~# '[ ~^:]'
    return 'no space, tilde ~, caret ^, or colon : are allowed'
  elseif a:commit =~# '[?[]' || (a:commit =~# '\*' && !get(a:options, 'refspec-pattern'))
    return 'no question ?, asterisk *, or open bracket [ are allowed'
  elseif (a:commit =~# '^/' || a:commit =~# '/$' || a:commit =~# '//\+') && !(get(a:options, 'normalize') || get(a:options, 'print'))
    return 'cannot begin or end with a slash /, or contain multiple consective slashes'
  elseif a:commit =~# '\.$'
    return 'cannot end with a dot .'
  elseif a:commit =~# '@{'
    return 'cannot contain a sequence @{'
  elseif a:commit =~# '^@$'
    return 'cannot be a single character @'
  elseif a:commit =~# '\'
    return 'cannot contain a backslash \'
  endif
  return ''
endfunction
function! s:is_valid_commitish(commitish, options) abort
  let result = s:split_commitish(a:commitish, a:options)
  if s:Prelude.is_string(result)
    return result
  endif
  return ''
endfunction
function! s:is_valid_treeish(treeish, options) abort
  let result = s:split_treeish(a:treeish, a:options)
  if s:Prelude.is_string(result)
    return result
  endif
  return ''
endfunction
function! s:is_valid_range(range, options) abort
  let result = s:split_range(a:range, a:options)
  if s:Prelude.is_string(result)
    return result
  endif
  return ''
endfunction

function! s:split_commitish(commitish, options) abort
  " https://www.kernel.org/pub/software/scm/git/docs/gitrevisions.html#_specifying_revisions
  " http://stackoverflow.com/questions/4044368/what-does-tree-ish-mean-in-git
  let options = get(a:000, 0, {})
  if a:commitish =~# '@{.*}$'
    let [commit, misc] = matchlist(a:commitish, '\(.\{-}\)\(@{.*}\)$')[1 : 2]
  elseif a:commitish =~# '\^[\^0-9]*$'
    let [commit, misc] = matchlist(a:commitish, '\(.\{-}\)\(\^[\^0-9]*\)$')[1 : 2]
  elseif a:commitish =~# '\~[\~0-9]*$'
    let [commit, misc] = matchlist(a:commitish, '\(.\{-}\)\(\~[\~0-9]*\)$')[1 : 2]
  elseif a:commitish =~# '\^{.*}$'
    let [commit, misc] = matchlist(a:commitish, '\(.\{-}\)\(\^{.*}\)$')[1 : 2]
  elseif a:commitish =~# ':/.*$'
    " NOTE:
    " Due to the bufname rule of vim-gita, it had not better to allow this type
    " of commitish assignment.
    let [commit, misc] = matchlist(a:commitish, '\(.\{-}\)\(:/.*\)$')[1 : 2]
  else
    let commit = a:commitish
    let misc = ''
  endif
  let errormsg = s:is_valid_commit(commit, a:options)
  return empty(errormsg) ? [commit, misc] : errormsg
endfunction
function! s:split_treeish(treeish, options) abort
  " https://www.kernel.org/pub/software/scm/git/docs/gitrevisions.html#_specifying_revisions
  " http://stackoverflow.com/questions/4044368/what-does-tree-ish-mean-in-git
  if a:treeish =~# '^:[0-3]:.*$'
    let commitish = ''
    let path = matchstr(a:treeish, '^:[0-3]:\zs.*$')
  elseif a:treeish =~# ':.*$'
    let [commitish, path] = matchlist(a:treeish, '\(.\{-}\):\(.*\)$')[1 : 2]
  else
    let commitish = a:treeish
    let path = ''
  endif
  let errormsg = s:is_valid_commitish(commitish, a:options)
  return empty(errormsg) ? [commitish, path] : errormsg
endfunction
function! s:split_range(range, options) abort
  if a:range =~# '^.\{-}\.\.\..*$'
    let [lhs, rhs] = matchlist(a:range, '^\(.\{-}\)\.\.\.\(.*\)$')[1 : 2]
  elseif a:range =~# '^.\{-}\.\..*$'
    let [lhs, rhs] = matchlist(a:range, '^\(.\{-}\)\.\.\(.*\)$')[1 : 2]
  else
    let lhs = a:range
    let rhs = ''
  endif
  let errormsg = s:is_valid_commitish(lhs, a:options)
  if !empty(errormsg)
    return errormsg
  endif
  let errormsg = s:is_valid_commitish(rhs, a:options)
  if !empty(errormsg)
    return errormsg
  endif
  return [lhs, rhs]
endfunction


function! hita#variable#split_commitish(commitish, ...) abort
  let options = get(a:000, 0, {})
  let result = s:split_commitish(a:commitish, options)
  if s:Prelude.is_string(result)
    call s:throw(result)
  endif
  return result
endfunction
function! hita#variable#split_treeish(treeish, ...) abort
  let options = get(a:000, 0, {})
  let result = s:split_treeish(a:treeish, options)
  if s:Prelude.is_string(result)
    call s:throw(result)
  endif
  return result
endfunction
function! hita#variable#split_range(range, ...) abort
  let options = get(a:000, 0, {})
  let result = s:split_range(a:range, options)
  if s:Prelude.is_string(result)
    call s:throw(result)
  endif
  return result
endfunction

function! hita#variable#validate_commit(commit, ...) abort
  let options = get(a:000, 0, {})
  let errormsg = s:is_valid_commit(a:commit, options)
  if empty(errormsg)
    return
  endif
  call s:throw(errormsg)
endfunction
function! hita#variable#validate_commitish(commitish, ...) abort
  let options = get(a:000, 0, {})
  let errormsg = s:is_valid_commitish(a:commitish, options)
  if empty(errormsg)
    return
  endif
  call hita#util#validate#throw(errormsg)
endfunction
function! hita#variable#validate_treeish(treeish, ...) abort
  let options = get(a:000, 0, {})
  let errormsg = s:is_valid_treeish(a:treeish, options)
  if empty(errormsg)
    return
  endif
  call hita#util#validate#throw(errormsg)
endfunction
function! hita#variable#validate_range(range, ...) abort
  let options = get(a:000, 0, {})
  let errormsg = s:is_valid_range(a:range, options)
  if empty(errormsg)
    return
  endif
  call hita#util#validate#throw(errormsg)
endfunction
function! hita#variable#validate_filename(filename, ...) abort
  let options = get(a:000, 0, {})
  call hita#util#validate#not_empty(
        \ a:filename,
        \ 'A filename cannot be empty',
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
  call hita#variable#validate_commit(commit, options)
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
  call hita#variable#validate_commitish(commitish, options)
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
  call hita#variable#validate_treeish(treeish, options)
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
  call hita#variable#validate_range(range, options)
  return range
endfunction
function! hita#variable#get_valid_filename(filename, ...) abort
  let options = get(a:000, 0, {})
  if empty(a:filename)
    let guard = s:Guard.store(['_complete_options', s:])
    let s:_complete_options = options
    try
      call histadd('input', hita#expand('%'))
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
    let filename = hita#core#expand(a:filename)
  endif
  call hita#variable#validate_filename(filename, options)
  return filename
endfunction

function! hita#variable#get_available_tags(hita, ...) abort
  let options = get(a:000, 0, {})
  let options = s:Dict.pick(options, [
        \ 'l', 'list',
        \ 'sort',
        \ 'contains', 'points-at',
        \])
  let result = hita#operation#exec(a:hita, 'tag', options)
  if result.status
    " fail silently
    call hita#util#prompt#debug(result.stdout)
    return []
  endif
  return split(result.stdout, '\r\?\n')
endfunction
function! hita#variable#get_available_branches(hita, ...) abort
  let options = get(a:000, 0, {})
  let options = s:Dict.pick(options, [
        \ 'a', 'all',
        \ 'list',
        \ 'merged', 'no-merged',
        \])
  let options['color'] = 'never'
  let result = hita#operation#exec(a:hita, 'branch', options)
  if result.status
    " fail silently
    call hita#util#prompt#debug(result.stdout)
    return []
  endif
  return map(split(result.stdout, '\r\?\n'), 'matchstr(v:val, "^..\\zs.*$")')
endfunction
function! hita#variable#get_available_commits(hita, ...) abort
  let options = get(a:000, 0, {})
  let options = s:Dict.pick(options, [
        \ 'author', 'committer',
        \ 'since', 'after',
        \ 'until', 'before',
        \])
  let options['pretty'] = '%h'
  let result = hita#operation#exec(a:hita, 'log', options)
  if result.status
    " fail silently
    call hita#util#prompt#debug(result.stdout)
    return []
  endif
  return split(result.stdout, '\r\?\n')
endfunction
function! hita#variable#get_available_filenames(hita, ...) abort
  let options = get(a:000, 0, {})
  " NOTE:
  " Remove unnecessary options from the below
  let options = s:Dict.pick(options, [
        \ 't',
        \ 'v',
        \ 'c', 'cached',
        \ 'd', 'deleted',
        \ 'm', 'modified',
        \ 'o', 'others',
        \ 'i', 'ignored',
        \ 's', 'staged',
        \ 'k', 'killed',
        \ 'u', 'unmerged',
        \ 'directory', 'empty-directory',
        \ 'resolve-undo',
        \ 'x', 'exclude',
        \ 'X', 'exclude-from',
        \ 'exclude-per-directory',
        \ 'exclude-standard',
        \ 'full-name',
        \ 'error-unmatch',
        \ 'with-tree',
        \ 'abbrev',
        \])
  let result = hita#operation#exec(a:hita, 'ls-files', options)
  if result.status
    " fail silently
    call hita#util#prompt#debug(result.stdout)
    return []
  endif
  return split(result.stdout, '\r\?\n')
endfunction

function! hita#variable#complete_commit(arglead, cmdline, cursorpos, ...) abort
  let options = get(s:, '_complete_options', {})
  let options = extend(options, get(a:000, 0, {}))
  let hita = hita#core#get()
  if hita.is_enabled()
    if !has_key(options, '_complete_branches')
      let options._complete_branches = hita#variable#get_available_branches(hita, options)
    endif
    if !has_key(options, '_complete_tags')
      let options._complete_tags = hita#variable#get_available_tags(hita, options)
    endif
    if !empty(a:arglead)
      if !has_key(options, '_complete_commits')
        let options._complete_commits = hita#variable#get_available_commits(hita, options)
      endif
      let commits = options._complete_branches + options._complete_tags + options._complete_commits
    else
      let commits = options._complete_branches + options._complete_tags
    endif
  else
    let commits = []
  endif
  return filter(commits, 'v:val =~# "^" . a:arglead')
endfunction
function! hita#variable#complete_filename(arglead, cmdline, cursorpos, ...) abort
  let options = get(s:, '_complete_options', {})
  let options = extend(options, get(a:000, 0, {}))
  let hita = hita#core#get()
  if hita.is_enabled()
    let filenames = hita#variable#get_available_filenames(hita, options)
  else
    let filenames = []
  endif
  return filter(filenames, 'v:val =~# "^" . a:arglead')
endfunction
