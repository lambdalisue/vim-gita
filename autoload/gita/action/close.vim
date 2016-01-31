let s:V = gita#vital()
let s:Anchor = s:V.import('Vim.Buffer.Anchor')
let s:MAPPING_TABLE = {
      \ '<Plug>(gita-close)': 'Close the buffer and focus an anchor',
      \}

function! gita#action#close#action(candidates, ...) abort
  let winnum = winnr()
  call s:Anchor.focus()
  execute printf('%dclose', winnum)
endfunction

function! gita#action#close#define_plugin_mappings() abort
  nnoremap <buffer><silent> <Plug>(gita-close)
        \ :<C-u>call gita#action#call('close')<CR>
endfunction

function! gita#action#close#define_default_mappings() abort
  nmap <buffer> q <Plug>(gita-close)
endfunction

function! gita#action#close#get_mapping_table() abort
  return s:MAPPING_TABLE
endfunction
