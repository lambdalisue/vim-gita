let s:V = gita#vital()
let s:MAPPING_TABLE = {
      \ '<Plug>(gita-redraw)': 'Redraw the buffer',
      \}

function! gita#action#redraw#action(candidates, ...) abort
  if &filetype =~# '^gita-'
    let name = matchstr(&filetype, '^gita-\zs.*$')
    let name = substitute(name, '-', '#', 'g')
    call call(function(printf('gita#command#%s#redraw', name)), [])
  endif
endfunction

function! gita#action#redraw#define_plugin_mappings() abort
  nnoremap <buffer><silent> <Plug>(gita-redraw)
        \ :<C-u>call gita#action#call('redraw')<CR>
endfunction

function! gita#action#redraw#define_default_mappings() abort
  nmap <buffer> <C-l> <Plug>(gita-redraw)
endfunction

function! gita#action#redraw#get_mapping_table() abort
  return s:MAPPING_TABLE
endfunction

call gita#util#define_variables('action#redraw', {})
