function! s:action(candidates, options) abort
  let options = extend({
        \ 'force': 0,
        \}, a:options)
  let git = gita#core#get_or_fail()
  let args = [
        \ 'add',
        \ '--ignore-errors',
        \ options.force ? '--force' : '',
        \ '--',
        \] + map(
        \ copy(a:candidates),
        \ 'gita#normalize#abspath(git, get(v:val, ''path2'', v:val.path))',
        \)
  let args = filter(args, '!empty(v:val)')
  call gita#process#execute(git, args, { 'quiet': 1 })
  call gita#trigger_modified()
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
