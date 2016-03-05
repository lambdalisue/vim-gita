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
  call gita#command#rm#call({
        \ 'quiet': 1,
        \ 'filenames': filenames,
        \ 'force': options.force,
        \})
endfunction

function! gita#action#rm#define(disable_mappings) abort
  call gita#action#define('rm', function('s:action'), {
        \ 'description': 'Remove files from the working tree and from the index',
        \ 'options': {},
        \})
  call gita#action#define('rm:force', function('s:action'), {
        \ 'description': 'Remove files from the working tree and from the index (force)',
        \ 'options': { 'force': 1 },
        \})
  if a:disable_mappings
    return
  endif
endfunction
