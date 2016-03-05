function! s:action(candidates, options) abort
  let options = extend({
        \ 'force': 0,
        \}, a:options)
  let filenames = []
  for candidate in a:candidates
    if has_key(candidate, 'path')
      call add(filenames, get(candidate, 'path2', candidate.path))
    endif
  endfor
  if empty(filenames)
    return
  endif
  call gita#command#add#call({
        \ 'quiet': 1,
        \ 'ignore-errors': 1,
        \ 'force': options.force,
        \ 'filenames': filenames,
        \})
endfunction

function! gita#action#add#define(disable_mappings) abort
  call gita#action#define('add', function('s:action'), {
        \ 'description': 'Add file contents to the index',
        \ 'options': {},
        \})
  call gita#action#define('add:force', function('s:action'), {
        \ 'description': 'Add file contents to the index (force)',
        \ 'options': { 'force': 1 },
        \})
  if a:disable_mappings
    return
  endif
endfunction
