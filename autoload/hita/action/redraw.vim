let s:V = hita#vital()
let s:MAPPING_TABLE = {
      \ '<Plug>(hita-redraw)': 'Redraw the buffer',
      \}

function! hita#action#redraw#action(candidates, ...) abort
  if &filetype =~# '^hita-'
    let name = matchstr(&filetype, '^hita-\zs.*$')
    call call(function(printf('hita#command#%s#redraw', name)), [])
  endif
endfunction

function! hita#action#redraw#define_plugin_mappings() abort
  nnoremap <buffer><silent> <Plug>(hita-redraw)
        \ :<C-u>call hita#action#call('redraw')<CR>
endfunction

function! hita#action#redraw#define_default_mappings() abort
  map <buffer> <C-l> <Plug>(hita-redraw)
endfunction

function! hita#action#redraw#get_mapping_table() abort
  return s:MAPPING_TABLE
endfunction

call hita#util#define_variables('action#redraw', {})
