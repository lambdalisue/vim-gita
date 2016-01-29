let s:V = hita#vital()
let s:MAPPING_TABLE = {
      \ '<Plug>(hita-status)': 'Open hita-status window',
      \}

function! hita#action#status#action(candidates, ...) abort
  let filenames = hita#get_meta('filenames', [])
  call hita#command#status#open({
        \ 'filenames': filenames,
        \})
endfunction

function! hita#action#status#define_plugin_mappings() abort
  noremap <buffer><silent> <Plug>(hita-status)
        \ :call hita#action#call('status')<CR>
endfunction

function! hita#action#status#define_default_mappings() abort
  map <buffer> cc <Plug>(hita-status)
endfunction

function! hita#action#status#get_mapping_table() abort
  return s:MAPPING_TABLE
endfunction

call hita#util#define_variables('action#status', {})

