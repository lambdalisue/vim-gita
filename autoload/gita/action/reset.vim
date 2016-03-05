function! s:action(candidates, options) abort
  let options = deepcopy(a:options)
  call gita#option#assign_commit(options)
  let options.commit = get(options, 'commit', '')
  let filenames = []
  for candidate in a:candidates
    if has_key(candidate, 'path')
      call add(filenames, candidate.path)
    endif
  endfor
  if !empty(filenames)
    call gita#command#reset#call({
          \ 'quiet': 1,
          \ 'commit': get(candidate, 'commit', options.commit),
          \ 'filenames': filenames,
          \})
  endif
endfunction

function! gita#action#reset#define(disable_mappings) abort
  call gita#action#define('reset', function('s:action'), {
        \ 'description': 'Reset changes on the index',
        \ 'options': {},
        \})
  if a:disable_mappings
    return
  endif
endfunction
