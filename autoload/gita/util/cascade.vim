let s:registry = {}

function! gita#util#cascade#set(name, value) abort
  let s:registry[a:name] = a:value
endfunction

function! gita#util#cascade#get(name) abort
  if empty(expand('<amatch>'))
    call gita#throw(printf(
          \ 'A cascade %s is requested from outside of autocmd',
          \ a:name,
          \))
  endif
  if has_key(s:registry, a:name)
    let value = s:registry[a:name]
    silent unlet s:registry[a:name]
    return value
  endif
  return {}
endfunction
