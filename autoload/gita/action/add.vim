function! s:action(candidates, options) abort
  let options = extend({
        \ 'force': 0,
        \}, a:options)
  let filenames = map(
        \ copy(a:candidates),
        \ 'fnameescape(get(v:val, "path2", v:val.path))',
        \)
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
        \ 'requirements': ['path'],
        \ 'options': {},
        \})
  call gita#action#define('add:force', function('s:action'), {
        \ 'description': 'Add file contents to the index (force)',
        \ 'requirements': ['path'],
        \ 'options': { 'force': 1 },
        \})
  if a:disable_mappings
    return
  endif
endfunction
