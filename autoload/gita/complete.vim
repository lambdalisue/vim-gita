let s:V = gita#vital()
let s:Path = s:V.import('System.Filepath')
let s:Prompt = s:V.import('Vim.Prompt')
let s:Git = s:V.import('Git')

function! s:clear_complete_cache() abort
  for git in gita#core#list()
    if git.is_enabled
      for key in filter(
            \ git.repository_cache.keys(),
            \ 'v:val =~# ''^gita#complete'''
            \)
        call git.repository_cache.remove(key)
      endfor
    endif
  endfor
endfunction

function! s:get_available_branches(git, args) abort
  let args = ['branch', '--no-color', '--list'] + a:args
  let content = gita#execute(a:git, args, {
        \ 'quiet': 1,
        \ 'fail_silently': 1,
        \})
  let content = filter(content, 'v:val !~# ''HEAD''')
  return map(content, 'matchstr(v:val, "^..\\zs.*$")')
endfunction

function! s:get_available_commits(git, args) abort
  let args = ['log', '--pretty=%h'] + a:args
  let content = gita#execute(a:git, args, {
        \ 'quiet': 1,
        \ 'fail_silently': 1,
        \})
  return content
endfunction

function! s:get_available_filenames(git, args) abort
  let args = [
        \ 'ls-files', '--full-name',
        \] + a:args
  let content = gita#execute(a:git, args, {
        \ 'quiet': 1,
        \ 'fail_silently': 1,
        \})
  " NOTE:
  " git -C <rep> ls-files returns unix relative paths from the repository
  " so make it relative from current working directory
  let prefix  = expand(a:git.worktree) . s:Path.separator()
  let content = map(content, 's:Path.realpath(prefix . v:val)')
  let content = map(content, 'fnamemodify(v:val, '':~:.'')')
  return content
endfunction

function! gita#complete#branch(arglead, cmdline, cursorpos, ...) abort
  try
    let git = gita#core#get_or_fail()
    let slug = matchstr(expand('<sfile>'), '\.\.\zs[^.]*$')
    let candidates = s:Git.get_cache_content(git, 'config', slug, [])
    if empty(candidates)
      let candidates = s:get_available_branches(git, ['--all'])
      call s:Git.set_cache_content(git, 'config', slug, candidates)
    endif
    return filter(copy(candidates), 'v:val =~# ''^'' . a:arglead')
  catch
    call s:Prompt.debug(v:exception)
    call s:Prompt.debug(v:throwpoint)
    return ''
  endtry
endfunction

function! gita#complete#local_branch(arglead, cmdline, cursorpos, ...) abort
  try
    let git = gita#core#get_or_fail()
    let slug = matchstr(expand('<sfile>'), '\.\.\zs[^.]*$')
    let candidates = s:Git.get_cache_content(git, 'config', slug, [])
    if empty(candidates)
      let candidates = s:get_available_branches(git, [])
      call s:Git.set_cache_content(git, 'config', slug, candidates)
    endif
    return filter(copy(candidates), 'v:val =~# ''^'' . a:arglead')
  catch
    call s:Prompt.debug(v:exception)
    call s:Prompt.debug(v:throwpoint)
    return ''
  endtry
endfunction

function! gita#complete#remote_branch(arglead, cmdline, cursorpos, ...) abort
  try
    let git = gita#core#get_or_fail()
    let slug = matchstr(expand('<sfile>'), '\.\.\zs[^.]*$')
    let candidates = s:Git.get_cache_content(git, 'config', slug, [])
    if empty(candidates)
      let candidates = s:get_available_branches(git, ['--remotes'])
      call s:Git.set_cache_content(git, 'config', slug, candidates)
    endif
    return filter(copy(candidates), 'v:val =~# ''^'' . a:arglead')
  catch
    call s:Prompt.debug(v:exception)
    call s:Prompt.debug(v:throwpoint)
    return ''
  endtry
endfunction

function! gita#complete#commit(arglead, cmdline, cursorpos, ...) abort
  try
    let git = gita#core#get_or_fail()
    let slug = matchstr(expand('<sfile>'), '\.\.\zs[^.]*$')
    let candidates = s:Git.get_cache_content(git, 'index', slug, [])
    if empty(candidates)
      let candidates = s:get_available_commits(git, [])
      call s:Git.set_cache_content(git, 'index', slug, candidates)
    endif
    return filter(copy(candidates), 'v:val =~# ''^'' . a:arglead')
  catch
    call s:Prompt.debug(v:exception)
    call s:Prompt.debug(v:throwpoint)
    return ''
  endtry
endfunction

function! gita#complete#cached_filename(arglead, cmdline, cursorpos, ...) abort
  try
    let git = gita#core#get_or_fail()
    let slug = matchstr(expand('<sfile>'), '\.\.\zs[^.]*$')
    let candidates = s:Git.get_cache_content(git, 'index', slug, [])
    if empty(candidates)
      let candidates = s:get_available_filenames(git, ['--cached'])
      call s:Git.set_cache_content(git, 'index', slug, candidates)
    endif
    return filter(copy(candidates), 'v:val =~# ''^'' . a:arglead')
  catch
    call s:Prompt.debug(v:exception)
    call s:Prompt.debug(v:throwpoint)
    return ''
  endtry
endfunction

function! gita#complete#deleted_filename(arglead, cmdline, cursorpos, ...) abort
  try
    let git = gita#core#get_or_fail()
    let slug = matchstr(expand('<sfile>'), '\.\.\zs[^.]*$')
    let candidates = s:Git.get_cache_content(git, 'index', slug, [])
    if empty(candidates)
      let candidates = s:get_available_filenames(git, ['--deleted'])
      call s:Git.set_cache_content(git, 'index', slug, candidates)
    endif
    return filter(copy(candidates), 'v:val =~# ''^'' . a:arglead')
  catch
    call s:Prompt.debug(v:exception)
    call s:Prompt.debug(v:throwpoint)
    return ''
  endtry
endfunction

function! gita#complete#modified_filename(arglead, cmdline, cursorpos, ...) abort
  try
    let git = gita#core#get_or_fail()
    let slug = matchstr(expand('<sfile>'), '\.\.\zs[^.]*$')
    let candidates = s:Git.get_cache_content(git, '.', slug, '')
    if empty(candidates)
      let candidates = s:get_available_filenames(git, ['--modified'])
      call s:Git.set_cache_content(git, '.', slug, candidates)
    endif
    return filter(copy(candidates), 'v:val =~# ''^'' . a:arglead')
  catch
    call s:Prompt.debug(v:exception)
    call s:Prompt.debug(v:throwpoint)
    return ''
  endtry
endfunction

function! gita#complete#others_filename(arglead, cmdline, cursorpos, ...) abort
  try
    let git = gita#core#get_or_fail()
    let candidates = s:get_available_filenames(git, [
          \ '--others', '--', a:arglead,
          \])
    return candidates
  catch
    call s:Prompt.debug(v:exception)
    call s:Prompt.debug(v:throwpoint)
    return ''
  endtry
endfunction

function! gita#complete#unstaged_filename(arglead, cmdline, cursorpos, ...) abort
  try
    let git = gita#core#get_or_fail()
    let candidates = s:get_available_filenames(git, [
          \ '--others', '--modified', '--', a:arglead,
          \])
    return candidates
  catch
    call s:Prompt.debug(v:exception)
    call s:Prompt.debug(v:throwpoint)
    return ''
  endtry
endfunction

function! gita#complete#filename(arglead, cmdline, cursorpos, ...) abort
  try
    let git = gita#core#get_or_fail()
    let candidates = s:get_available_filenames(git, [
          \ '--cached', '--others', '--', a:arglead,
          \])
    return filter(copy(candidates), 'v:val =~# ''^'' . a:arglead')
  catch
    call s:Prompt.debug(v:exception)
    call s:Prompt.debug(v:throwpoint)
    return ''
  endtry
endfunction

augroup vim_gita_internal_complete
  autocmd! *
  autocmd User GitaStatusModified * call s:clear_complete_cache()
augroup END
