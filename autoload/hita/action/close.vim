let s:V = hita#vital()
let s:Anchor = s:V.import('Vim.Buffer.Anchor')
let s:MAPPING_TABLE = {
      \ '<Plug>(hita-close)': 'Close the buffer and focus an anchor',
      \}

function! hita#action#close#action(candidates, ...) abort
  let winnum = winnr()
  call s:Anchor.focus()
  execute printf('%dclose', winnum)
endfunction

function! hita#action#close#define_plugin_mappings() abort
  nnoremap <buffer><silent> <Plug>(hita-close)
        \ :<C-u>call hita#action#call('close')<CR>
endfunction

function! hita#action#close#define_default_mappings() abort
  map <buffer> q <Plug>(hita-close)
endfunction

function! hita#action#close#get_mapping_table() abort
  return s:MAPPING_TABLE
endfunction
