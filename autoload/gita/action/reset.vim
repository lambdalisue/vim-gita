function! s:action(candidates, options) abort
  let options = deepcopy(a:options)
  call gita#option#assign_commit(options)
  let options.commit = get(options, 'commit', '')
  let filenames = map(copy(a:candidates), 'v:val.path')
  call gita#command#reset#call({
        \ 'quiet': 1,
        \ 'commit': options.commit,
        \ 'filenames': filenames,
        \})
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
