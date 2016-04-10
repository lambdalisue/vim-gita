function! s:_vital_loaded(V) abort
  let s:Prelude = a:V.import('Prelude')
  let s:GitInfo = a:V.import('Git.Info')

  let git_version = s:GitInfo.get_git_version()
  let major_version = str2nr(matchstr(git_version, '^\d\+'))
  let minor_version = str2float(matchstr(git_version, '^\d\+\.\zs\d\+\.\d\+'))
  let s:support_atmark_alias =
        \ major_version >= 2 ||
        \ (major_version == 1 && minor_version >= 8.5)
endfunction
function! s:_vital_depends() abort
  return ['Prelude', 'Git.Info']
endfunction

function! s:_throw(msg) abort
  throw 'vital: Git.Term: ' . a:msg
endfunction

function! s:_is_valid_commit(commit, options) abort
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
  elseif a:commit =~# '^@$' && !get(a:options, '_allow_atmark', s:support_atmark_alias)
    return 'cannot be a single character @'
  elseif a:commit =~# '\'
    return 'cannot contain a backslash \'
  endif
  return ''
endfunction
function! s:_is_valid_commitish(commitish, options) abort
  let result = s:_split_commitish(a:commitish, a:options)
  if s:Prelude.is_string(result)
    return result
  endif
  return ''
endfunction
function! s:_is_valid_treeish(treeish, options) abort
  let result = s:_split_treeish(a:treeish, a:options)
  if s:Prelude.is_string(result)
    return result
  endif
  return ''
endfunction
function! s:_is_valid_range(range, options) abort
  let result = s:_split_range(a:range, a:options)
  if s:Prelude.is_string(result)
    return result
  endif
  return ''
endfunction

function! s:_split_commitish(commitish, options) abort
  " https://www.kernel.org/pub/software/scm/git/docs/gitrevisions.html#_specifying_revisions
  " http://stackoverflow.com/questions/4044368/what-does-tree-ish-mean-in-git
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
    " Due to the bufname rule of gita, it had not better to allow this type
    " of commitish assignment.
    let [commit, misc] = matchlist(a:commitish, '\(.\{-}\)\(:/.*\)$')[1 : 2]
  else
    let commit = a:commitish
    let misc = ''
  endif
  let errormsg = s:_is_valid_commit(commit, a:options)
  return empty(errormsg) ? [commit, misc] : errormsg
endfunction
function! s:_split_treeish(treeish, options) abort
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
  if get(a:options, '_allow_range')
    let errormsg = s:_is_valid_range(commitish, a:options)
  else
    let errormsg = s:_is_valid_commitish(commitish, a:options)
  endif
  return empty(errormsg) ? [commitish, path] : errormsg
endfunction
function! s:_split_range(range, options) abort
  if a:range =~# '^.\{-}\.\.\..*$'
    let [lhs, rhs] = matchlist(a:range, '^\(.\{-}\)\.\.\.\(.*\)$')[1 : 2]
  elseif a:range =~# '^.\{-}\.\..*$'
    let [lhs, rhs] = matchlist(a:range, '^\(.\{-}\)\.\.\(.*\)$')[1 : 2]
  else
    let lhs = a:range
    let rhs = ''
  endif
  let errormsg = s:_is_valid_commitish(lhs, a:options)
  if !empty(errormsg)
    return errormsg
  endif
  let errormsg = s:_is_valid_commitish(rhs, a:options)
  if !empty(errormsg)
    return errormsg
  endif
  return [lhs, rhs]
endfunction


function! s:split_commitish(commitish, ...) abort
  let options = get(a:000, 0, {})
  let result = s:_split_commitish(a:commitish, options)
  if s:Prelude.is_string(result)
    call s:_throw('ValidationError: ' . result)
  endif
  return result
endfunction
function! s:split_treeish(treeish, ...) abort
  let options = get(a:000, 0, {})
  let result = s:_split_treeish(a:treeish, options)
  if s:Prelude.is_string(result)
    call s:_throw('ValidationError: ' . result)
  endif
  return result
endfunction
function! s:split_range(range, ...) abort
  let options = get(a:000, 0, {})
  let result = s:_split_range(a:range, options)
  if s:Prelude.is_string(result)
    call s:_throw('ValidationError: ' . result)
  endif
  return result
endfunction

function! s:validate_commit(commit, ...) abort
  let options = get(a:000, 0, {})
  let errormsg = s:_is_valid_commit(a:commit, options)
  if empty(errormsg)
    return
  endif
  call s:_throw('ValidationError: ' . errormsg)
endfunction
function! s:validate_commitish(commitish, ...) abort
  let options = get(a:000, 0, {})
  let errormsg = s:_is_valid_commitish(a:commitish, options)
  if empty(errormsg)
    return
  endif
  call s:_throw('ValidationError: ' . errormsg)
endfunction
function! s:validate_treeish(treeish, ...) abort
  let options = get(a:000, 0, {})
  let errormsg = s:_is_valid_treeish(a:treeish, options)
  if empty(errormsg)
    return
  endif
  call s:_throw('ValidationError: ' . errormsg)
endfunction
function! s:validate_range(range, ...) abort
  let options = get(a:000, 0, {})
  let errormsg = s:_is_valid_range(a:range, options)
  if empty(errormsg)
    return
  endif
  call s:_throw('ValidationError: ' . errormsg)
endfunction
