let s:V = gita#vital()
let s:File = s:V.import('System.File')
let s:Path = s:V.import('System.Filepath')
let s:Console = s:V.import('Vim.Console')

function! s:action(candidates, options) abort
  let options = extend({
        \ 'force': 0,
        \}, a:options)
  let delete_candidates = []
  let checkout_candidates = []
  for candidate in a:candidates
    if candidate.is_conflicted
      call s:Console.warn(printf(
            \ 'A conflicted file "%s" cannot be discarded. Resolve conflict first.',
            \ s:Path.relpath(candidate.path),
            \))
      continue
    elseif candidate.is_untracked || candidate.is_ignored
      call add(delete_candidates, candidate)
    elseif candidate.is_staged || candidate.is_unstaged
      call add(checkout_candidates, candidate)
    endif
  endfor
  if !options.force
    call s:Console.warn(
          \ 'A discard action will discard all local changes on the working tree',
          \ 'and the operation is irreversible, mean that you have no chance to',
          \ 'revert the operation.',
          \)
    echo 'This operation will be performed to the following candidates:'
    for candidate in extend(copy(delete_candidates), checkout_candidates)
      echo '- ' . s:Path.relpath(candidate.path)
    endfor
    if !s:Console.confirm('Are you sure to discard the changes?')
      call gita#throw('Cancel: The operation has canceled by user')
    endif
  endif
  " delete untracked files
  for candidate in delete_candidates
    if isdirectory(candidate.path)
      call s:File.rmdir(candidate.path, 'r')
    elseif filewritable(candidate.path)
      call delete(candidate.path)
    endif
  endfor
  " checkout tracked files from HEAD
  noautocmd call gita#action#call('checkout:HEAD:force', checkout_candidates)
  call gita#trigger_modified()
endfunction

function! gita#action#discard#define(disable_mapping) abort
  call gita#action#define('discard', function('s:action'), {
        \ 'description': 'Discard changes on the working tree',
        \ 'requirements': [
        \   'path',
        \   'is_conflicted',
        \   'is_staged',
        \   'is_unstaged',
        \   'is_untracked',
        \   'is_ignored',
        \ ],
        \ 'options': {},
        \})
  call gita#action#define('discard:force', function('s:action'), {
        \ 'description': 'Discard changes on the working tree (force)',
        \ 'requirements': [
        \   'path',
        \   'is_conflicted',
        \   'is_staged',
        \   'is_unstaged',
        \   'is_untracked',
        \   'is_ignored',
        \ ],
        \ 'options': { 'force': 1 },
        \})
  if a:disable_mapping
    return
  endif
  nmap <buffer><nowait><expr> == gita#action#smart_map('==', '<Plug>(gita-discard)')
  vmap <buffer><nowait><expr> == gita#action#smart_map('==', '<Plug>(gita-discard)')
endfunction
