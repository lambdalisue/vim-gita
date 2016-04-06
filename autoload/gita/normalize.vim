let s:V = gita#vital()
let s:Path = s:V.import('System.Filepath')
let s:Git = s:V.import('Git')
let s:GitInfo = s:V.import('Git.Info')
let s:GitTerm = s:V.import('Git.Term')

" NOTE:
" git requires an unix relative path from the repository often
function! gita#normalize#relpath(git, path) abort
  let path = a:git.is_enabled
        \ ? s:Git.relpath(a:git, gita#meta#expand(a:path))
        \ : s:Path.relpath(gita#meta#expand(a:path))
  return s:Path.unixpath(path)
endfunction

" NOTE:
" system requires a real absolute path often
function! gita#normalize#abspath(git, path) abort
  let path = a:git.is_enabled
        \ ? s:Git.abspath(a:git, gita#meta#expand(a:path))
        \ : s:Path.abspath(gita#meta#expand(a:path))
  return s:Path.realpath(path)
endfunction

" NOTE:
" most of git command does not understand A...B type assignment so translate
" it to an exact revision
function! gita#normalize#commit(git, commit) abort
  if a:commit =~# '^.\{-}\.\.\..\{-}$'
    " git diff <lhs>...<rhs> : <lhs>...<rhs> vs <rhs>
    let [lhs, rhs] = s:GitTerm.split_range(a:commit)
    let lhs = empty(lhs) ? 'HEAD' : lhs
    let rhs = empty(rhs) ? 'HEAD' : rhs
    return s:GitInfo.find_common_ancestor(a:git, lhs, rhs)
  elseif a:commit =~# '^.\{-}\.\..\{-}$'
    return s:GitTerm.split_range(a:commit)[0]
  else
    return a:commit
  endif
endfunction

" NOTE:
" git diff command does not understand A...B type assignment so translate
" it to an exact revision
function! gita#normalize#commit_for_diff(git, commit) abort
  if a:commit =~# '^.\{-}\.\.\..\{-}$'
    " git diff <lhs>...<rhs> : <lhs>...<rhs> vs <rhs>
    let [lhs, rhs] = s:GitTerm.split_range(a:commit)
    let lhs = empty(lhs) ? 'HEAD' : lhs
    let rhs = empty(rhs) ? 'HEAD' : rhs
    let lhs = s:GitInfo.find_common_ancestor(a:git, lhs, rhs)
    return lhs . '..' . rhs
  else
    return a:commit
  endif
endfunction
