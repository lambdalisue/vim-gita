function! s:_vital_loaded(V) abort
  let s:Path = a:V.import('System.Filepath')
endfunction
function! s:_vital_depends() abort
  return ['System.Filepath']
endfunction

function! s:readfile(path) abort
  return filereadable(a:path) ? readfile(a:path) : []
endfunction
function! s:readline(path) abort
  return get(s:readfile(a:path), 0, '')
endfunction

function! s:fnamemodify(path, mods) abort
  if empty(a:path)
    return ''
  endif
  return s:Path.remove_last_separator(fnamemodify(a:path, a:mods))
endfunction
function! s:dirpath(path) abort
  if empty(a:path)
    return ''
  endif
  let abspath = s:Path.abspath(a:path)
  let dirpath = isdirectory(abspath) ? abspath : fnamemodify(abspath, ':h')
  return s:Path.remove_last_separator(dirpath)
endfunction
