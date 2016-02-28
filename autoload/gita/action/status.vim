let s:V = gita#vital()
let s:MAPPING_TABLE = {
      \ '<Plug>(gita-status)': 'Open gita-status window',
      \}

function! gita#action#status#action(candidates, ...) abort
  let filenames = gita#get_meta('filenames', [])
  call gita#command#status#open({
        \ 'filenames': filenames,
        \})
endfunction

function! gita#action#status#define_plugin_mappings() abort
  noremap <buffer><silent> <Plug>(gita-status)
        \ :call gita#action#call('status')<CR>
endfunction

function! gita#action#status#define_default_mappings() abort
endfunction

function! gita#action#status#get_mapping_table() abort
  return s:MAPPING_TABLE
endfunction

call gita#util#define_variables('action#status', {})

