function! s:_vital_loaded(V) abort
  let s:Path = a:V.import('System.Filepath')
  let s:Dict = a:V.import('Data.Dict')
  let s:Git = a:V.import('Git')
  let s:Operation = a:V.import('Git.Operation')
endfunction
function! s:_vital_depends() abort
  return ['System.Filepath', 'Data.Dict', 'Git', 'Git.Operation']
endfunction

function! s:_throw(msg) abort
  throw 'vital: Git.Candidate: ' . a:msg
endfunction

function! s:get_available_tags(git, ...) abort
  let options = extend({
        \ 'fail_silently': 0,
        \ 'force': 0,
        \}, get(a:000, 0, {}))
  let execute_options = s:Dict.pick(options, [
          \ 'l', 'list',
          \ 'sort',
          \ 'contains', 'points-at',
          \])
  let slug = 'operation:get_available_tags:' . string(execute_options)
  let content = s:Git.get_cached_content(a:git, 'index', slug, [])
  if options.force || empty(content)
    let result = s:Operation.execute(a:git, 'tag', execute_options)
    if result.status
      if options.fail_silently
        return []
      endif
      call s:_throw(result.stdout)
    endif
    let content = result.content
    call s:Git.set_cached_content(a:git, 'index', slug, content)
  endif
  return content
endfunction

function! s:get_available_branches(git, ...) abort
  let options = extend({
        \ 'fail_silently': 0,
        \ 'force': 0,
        \}, get(a:000, 0, {}))
  let execute_options = s:Dict.pick(options, [
        \ 'a', 'all',
        \ 'list',
        \ 'merged', 'no-merged',
        \ 'color',
        \])
  let slug = 'operation:get_available_branches:' . string(execute_options)
  let content = s:Git.get_cached_content(a:git, 'index', slug, [])
  if options.force || empty(content)
    let execute_options['color'] = 'never'
    let result = s:Operation.execute(a:git, 'branch', execute_options)
    if result.status
      if options.fail_silently
        return []
      endif
      call s:_throw(result.stdout)
    endif
    let content = map(result.content, 'matchstr(v:val, "^..\\zs.*$")')
    call s:Git.set_cached_content(a:git, 'index', slug, content)
  endif
  return content
endfunction

function! s:get_available_commits(git, ...) abort
  let options = extend({
        \ 'fail_silently': 0,
        \ 'force': 0,
        \}, get(a:000, 0, {}))
  let execute_options = s:Dict.pick(options, [
        \ 'author', 'committer',
        \ 'since', 'after',
        \ 'until', 'before',
        \ 'pretty',
        \])
  let slug = 'operation:get_available_commits:' . string(execute_options)
  let content = s:Git.get_cached_content(a:git, 'index', slug, [])
  if options.force || empty(content)
    let execute_options['pretty'] = '%h'
    let result = s:Operation.execute(a:git, 'log', execute_options)
    if result.status
      if options.fail_silently
        return []
      endif
      call s:_throw(result.stdout)
    endif
    let content = result.content
    call s:Git.set_cached_content(a:git, 'index', slug, content)
  endif
  return content
endfunction

function! s:get_available_filenames(git, ...) abort
  let options = extend({
        \ 'fail_silently': 0,
        \ 'force': 0,
        \}, get(a:000, 0, {}))
  " NOTE:
  " Remove unnecessary options
  let execute_options = s:Dict.pick(options, [
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
  let slug = 'operation:get_available_filenames:' . string(execute_options)
  let content = s:Git.get_cached_content(a:git, 'index', slug, [])
  if options.force || empty(content)
    " NOTE:
    " git -C <rep> ls-files returns unix relative paths from the repository
    let result = s:Operation.execute(a:git, 'ls-files', execute_options)
    if result.status
      if options.fail_silently
        return []
      endif
      call s:_throw(result.stdout)
    endif
    " return real absolute paths
    let prefix = expand(a:git.worktree) . s:Path.separator()
    let content = map(result.content, 's:Path.realpath(prefix . v:val)')
    call s:Git.set_cached_content(a:git, 'index', slug, content)
  endif
  return content
endfunction
