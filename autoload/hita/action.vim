function! hita#action#define(fn) abort
  let action = {
        \ 'get_entry': a:fn,
        \ 'actions': {},
        \}
  let b:_hita_action = action
  return action
endfunction

function! hita#action#get() abort
  if !exists('b:_hita_action')
    call hita#throw(printf(
          \ '"b:_hita_action on %s is not defined.', bufname('%')
          \))
  endif
  return b:_hita_action
endfunction

function! hita#action#call(name, ...) abort range
  let action = hita#action#get()
  let candidates = map(
        \ copy(range(a:firstline, a:lastline)),
        \ 'action.get_entry(v:val - 1)'
        \)
  call filter(candidates, '!empty(v:val)')
  let args = [candidates] + a:000
  if has_key(action.actions, a:name)
    call call(action.actions[a:name], args, action.actions)
  else
    call call(function(printf('hita#command#%s#action', a:name)), args)
  endif
endfunction
