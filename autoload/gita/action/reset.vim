function! s:action(candidates, options) abort
  let git = gita#core#get_or_fail()
  let args = ['reset', '--'] + map(
        \ copy(a:candidates),
        \ 'gita#normalize#relpath(git, v:val.path)',
        \)
  let args = filter(args, '!empty(v:val)')
  call gita#process#execute(git, args, { 'quiet': 1 })
  call gita#trigger_modified()
endfunction

function! gita#action#reset#define(disable_mappings) abort
  call gita#action#define('reset', function('s:action'), {
        \ 'description': 'Reset changes on the index',
        \ 'requirements': ['path'],
        \ 'options': {},
        \})
  if a:disable_mappings
    return
  endif
endfunction
