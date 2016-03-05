function! s:is_available(candidate) abort
  let necessary_attributes = [
      \ 'is_remote',
      \ 'is_selected',
      \ 'name',
      \ 'remote',
      \ 'linkto',
      \ 'record',
      \]
  for attribute in necessary_attributes
    if !has_key(a:candidate, attribute)
      return 0
    endif
  endfor
  return 1
endfunction

function! s:action(candidates, options) abort
  let branch_names = []
  for candidate in a:candidates
    if s:is_available(candidate)
      call add(branch_names, candidate.name)
    endif
  endfor
  if empty(branch_names)
    return
  endif
  call gita#throw('Not implemented yet')
endfunction

function! gita#action#branch#define(disable_mapping) abort
  if a:disable_mapping
    return
  endif
endfunction

