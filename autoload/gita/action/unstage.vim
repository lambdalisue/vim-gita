let s:V = gita#vital()
let s:MAPPING_TABLE = {
      \ '<Plug>(gita-unstage)': 'Unstage changes from the index',
      \}

function! gita#action#unstage#action(candidates, ...) abort
  call gita#action#do('reset', a:candidates, {})
endfunction

function! gita#action#unstage#define_plugin_mappings() abort
  noremap <buffer><silent> <Plug>(gita-unstage)
        \ :call gita#action#call('unstage')<CR>
endfunction

function! gita#action#unstage#define_default_mappings() abort
  map <buffer><expr> >> gita#action#smart_map('>>', '<Plug>(gita-unstage)')
endfunction

function! gita#action#unstage#get_mapping_table() abort
  return s:MAPPING_TABLE
endfunction

call gita#util#define_variables('action#unstage', {})
