let s:V = hita#vital()
let s:MAPPING_TABLE = {
      \ '<Plug>(hita-unstage)': 'Unstage changes from the index',
      \}

function! hita#action#unstage#action(candidates, ...) abort
  call hita#action#do('reset', a:candidates, {})
endfunction

function! hita#action#unstage#define_plugin_mappings() abort
  noremap <buffer><silent> <Plug>(hita-unstage)
        \ :call hita#action#call('unstage')<CR>
endfunction

function! hita#action#unstage#define_default_mappings() abort
  map <buffer> >> <Plug>(hita-unstage)
endfunction

function! hita#action#unstage#get_mapping_table() abort
  return s:MAPPING_TABLE
endfunction

call hita#util#define_variables('action#unstage', {})
