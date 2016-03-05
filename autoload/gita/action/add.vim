let s:V = gita#vital()
let s:MAPPING_TABLE = {
      \ '<Plug>(gita-add)': 'Add file contents to the index',
      \ '<Plug>(gita-ADD)': 'Add file contents to the index (force)',
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
    call gita#command#add#call({
          \ 'quiet': 1,
          \ 'filenames': filenames,
          \ 'force': options.force,
          \ 'ignore-errors': 1,
          \})
  endif
endfunction

function! gita#action#add#define_plugin_mappings() abort
  noremap <buffer><silent> <Plug>(gita-add)
        \ :call gita#action#call('add')<CR>
  noremap <buffer><silent> <Plug>(gita-ADD)
        \ :call gita#action#call('add', { 'force': 1 })<CR>
endfunction

function! gita#action#add#define_default_mappings() abort
  map <buffer><nowait><expr> -a gita#action#smart_map('-a', '<Plug>(gita-add)')
  map <buffer><nowait><expr> -A gita#action#smart_map('-A', '<Plug>(gita-ADD)')
endfunction

function! gita#action#add#get_mapping_table() abort
  return s:MAPPING_TABLE
endfunction
