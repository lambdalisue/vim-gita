let s:V = gita#vital()
let s:MAPPING_TABLE = {
      \ '<Plug>(gita-checkout)': 'Checkout contents to the working tree',
      \ '<Plug>(gita-CHECKOUT)': 'Checkout contents to the working tree (force)',
      \ '<Plug>(gita-checkout-ours)': 'Checkout contents of "ours" to the working tree',
      \ '<Plug>(gita-CHECKOUT-OURS)': 'Checkout contents or "ours" to the working tree (force)',
      \ '<Plug>(gita-checkout-theirs)': 'Checkout contents of "theirs" to the working tree',
      \ '<Plug>(gita-CHECKOUT-THEIRS)': 'Checkout contents or "theirs" to the working tree (force)',
      \}

function! gita#action#checkout#action(candidates, ...) abort
  let options = extend({
        \ 'force': 0,
        \ 'ours': 0,
        \ 'theirs': 0,
        \}, get(a:000, 0, {}))
  call gita#option#assign_commit(options)
  let git = gita#get_or_fail()
  let filenames = []
  for candidate in a:candidates
    if has_key(candidate, 'path')
      call add(filenames, candidate.path)
    endif
  endfor
  if !empty(filenames)
    let result = gita#command#checkout#call({
          \ 'commit': get(options, 'commit', ''),
          \ 'filenames': filenames,
          \ 'force': options.force,
          \ 'ours': options.ours,
          \ 'theirs': options.theirs,
          \ 'quiet': 1,
          \})
    " TODO: Show some success message?
  endif
endfunction

function! gita#action#checkout#define_plugin_mappings() abort
  noremap <buffer><silent> <Plug>(gita-checkout)
        \ :call gita#action#call('checkout')<CR>
  noremap <buffer><silent> <Plug>(gita-CHECKOUT)
        \ :call gita#action#call('checkout', { 'force': 1 })<CR>
  noremap <buffer><silent> <Plug>(gita-checkout-ours)
        \ :call gita#action#call('checkout', { 'ours': 1 })<CR>
  noremap <buffer><silent> <Plug>(gita-CHECKOUT-OURS)
        \ :call gita#action#call('checkout', { 'force': 1, 'ours': 1 })<CR>
  noremap <buffer><silent> <Plug>(gita-checkout-theirs)
        \ :call gita#action#call('checkout', { 'theirs': 1 })<CR>
  noremap <buffer><silent> <Plug>(gita-CHECKOUT-THEIRS)
        \ :call gita#action#call('checkout', { 'force': 1, 'theirs': 1 })<CR>
endfunction

function! gita#action#checkout#define_default_mappings() abort
  map <buffer><nowait><expr> -c gita#action#smart_map('-c', '<Plug>(gita-checkout)')
  map <buffer><nowait><expr> -C gita#action#smart_map('-C', '<Plug>(gita-CHECKOUT)')
  map <buffer><nowait><expr> -o gita#action#smart_map('-o', '<Plug>(gita-checkout-ours)')
  map <buffer><nowait><expr> -O gita#action#smart_map('-O', '<Plug>(gita-CHECKOUT-OURS)')
  map <buffer><nowait><expr> -t gita#action#smart_map('-t', '<Plug>(gita-checkout-theirs)')
  map <buffer><nowait><expr> -T gita#action#smart_map('-T', '<Plug>(gita-CHECKOUT-THEIRS)')
endfunction

function! gita#action#checkout#get_mapping_table() abort
  return s:MAPPING_TABLE
endfunction

call gita#util#define_variables('action#checkout', {})

