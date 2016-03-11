function! gita#command#ui#add#open(...) abort
  let options = extend({
        \ 'edit': 0,
        \}, get(a:000, 0, {}))
  let method = options.edit ? 'one' : 'two'
  call gita#command#ui#patch#open(extend({
        \ 'method': method,
        \}, options)
        \)
endfunction
