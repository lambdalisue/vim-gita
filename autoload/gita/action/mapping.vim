let s:V = gita#vital()
let s:MAPPING_TABLE = {
      \ '<Plug>(gita-mapping)': 'Toggle mapping help',
      \}

function! gita#action#mapping#get_visibility() abort
  if !exists('b:_gita_mapping_visibility')
    call gita#action#mapping#set_visibility(
          \ g:gita#action#mapping#default_visibility
          \)
  endif
  return b:_gita_mapping_visibility
endfunction

function! gita#action#mapping#set_visibility(visibility) abort
  let b:_gita_mapping_visibility = a:visibility
endfunction

function! gita#action#mapping#toggle_visibility() abort
  call gita#action#mapping#set_visibility(
        \ !gita#action#mapping#get_visibility()
        \)
endfunction


function! gita#action#mapping#action(candidates, ...) abort
  call gita#action#mapping#toggle_visibility()
  call gita#action#do('redraw', [])
endfunction

function! gita#action#mapping#define_plugin_mappings() abort
  nnoremap <buffer><silent> <Plug>(gita-mapping)
        \ :<C-u>call gita#action#call('mapping')<CR>
endfunction

function! gita#action#mapping#define_default_mappings() abort
  map <buffer> ? <Plug>(gita-mapping)
endfunction

function! gita#action#mapping#get_mapping_table() abort
  return s:MAPPING_TABLE
endfunction

call gita#util#define_variables('action#mapping', {
      \ 'default_visibility': 0,
      \})
