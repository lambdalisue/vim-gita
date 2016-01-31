let s:V = gita#vital()
let s:MAPPING_TABLE = {
      \ '<Plug>(gita-add)': 'Add changes into an index',
      \ '<Plug>(gita-ADD)': 'Add changes into an index (force)',
      \}

function! gita#action#add#action(candidates, ...) abort
  let options = extend({
        \ 'force': 0,
        \}, get(a:000, 0, {}))
  let filenames = []
  for candidate in a:candidates
    if has_key(candidate, 'path')
      call add(filenames, get(candidate, 'path2', candidate.path))
    endif
  endfor
  if !empty(filenames)
    let result = gita#command#add#call({
          \ 'filenames': filenames,
          \ 'force': options.force,
          \ 'ignore-errors': 1,
          \})
    " TODO: Show some success message?
  endif
endfunction

function! gita#action#add#define_plugin_mappings() abort
  noremap <buffer><silent> <Plug>(gita-add)
        \ :call gita#action#call('add')<CR>
  noremap <buffer><silent> <Plug>(gita-ADD)
        \ :call gita#action#call('add', { 'force': 1 })<CR>
endfunction

function! gita#action#add#define_default_mappings() abort
  map <buffer> -a <Plug>(gita-add)
  map <buffer> -A <Plug>(gita-ADD)
endfunction

function! gita#action#add#get_mapping_table() abort
  return s:MAPPING_TABLE
endfunction

call gita#util#define_variables('action#add', {})
