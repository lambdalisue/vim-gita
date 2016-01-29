let s:V = hita#vital()
let s:MAPPING_TABLE = {
      \ '<Plug>(hita-mapping)': 'Toggle mapping help',
      \}

function! hita#action#mapping#get_visibility() abort
  if !exists('b:_hita_mapping_visibility')
    call hita#action#mapping#set_visibility(
          \ g:hita#action#mapping#default_visibility
          \)
  endif
  return b:_hita_mapping_visibility
endfunction

function! hita#action#mapping#set_visibility(visibility) abort
  let b:_hita_mapping_visibility = a:visibility
endfunction

function! hita#action#mapping#toggle_visibility() abort
  call hita#action#mapping#set_visibility(
        \ !hita#action#mapping#get_visibility()
        \)
endfunction


function! hita#action#mapping#action(candidates, ...) abort
  call hita#action#mapping#toggle_visibility()
  call hita#action#do('redraw', [])
endfunction

function! hita#action#mapping#define_plugin_mappings() abort
  nnoremap <buffer><silent> <Plug>(hita-mapping)
        \ :<C-u>call hita#action#call('mapping')<CR>
endfunction

function! hita#action#mapping#define_default_mappings() abort
  map <buffer> ? <Plug>(hita-mapping)
endfunction

function! hita#action#mapping#get_mapping_table() abort
  return s:MAPPING_TABLE
endfunction

call hita#util#define_variables('action#mapping', {
      \ 'default_visibility': 0,
      \})
