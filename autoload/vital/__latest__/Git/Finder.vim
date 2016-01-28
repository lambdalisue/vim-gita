function! s:_vital_loaded(V) abort
  let s:Prelude = a:V.import('Prelude')
  let s:Dict = a:V.import('Data.Dict')
  let s:StringExt = a:V.import('Data.String.Extra')
  let s:Path = a:V.import('System.Filepath')
  let s:Util = a:V.import('Git.Util')
endfunction
function! s:_vital_depends() abort
  return [
        \ 'Prelude',
        \ 'Data.Dict',
        \ 'Data.String.Extra',
        \ 'System.Filepath',
        \ 'System.Cache',
        \ 'Git.Util',
        \]
endfunction

function! s:_find_worktree(dirpath) abort
  let dgit = s:Util.fnamemodify(finddir('.git', a:dirpath . ';'), ':p:h')
  let fgit = s:Util.fnamemodify(findfile('.git', a:dirpath . ';'), ':p')
  " inside '.git' directory is not a working directory
  let dgit = a:dirpath =~# '^' . s:StringExt.escape_regex(dgit) ? '' : dgit
  " use deepest dotgit found
  let dotgit = strlen(dgit) >= strlen(fgit) ? dgit : fgit
  return strlen(dotgit) ? s:Util.fnamemodify(dotgit, ':h') : ''
endfunction
function! s:_find_repository(worktree) abort
  let dotgit = s:Path.join([s:Util.fnamemodify(a:worktree, ':p'), '.git'])
  if isdirectory(dotgit)
    return dotgit
  elseif filereadable(dotgit)
    " in case if the found '.git' is a file which was created via
    " '--separate-git-dir' option
    let lines = readfile(dotgit)
    if !empty(lines)
      let gitdir = matchstr(lines[0], '^gitdir:\s*\zs.\+$')
      let is_abs = s:Path.is_absolute(gitdir)
      return s:Util.fnamemodify((is_abs ? gitdir : dotgit[:-5] . gitdir), ':p:h')
    endif
  endif
  return ''
endfunction

function! s:find(path) abort
  let path = s:Util.dirpath(s:Path.realpath(a:path))
  let worktree = s:_find_worktree(path)
  let repository = strlen(worktree) ? s:_find_repository(worktree) : ''
  let meta = {
        \ 'worktree': worktree,
        \ 'repository': repository,
        \}
  return meta
endfunction
