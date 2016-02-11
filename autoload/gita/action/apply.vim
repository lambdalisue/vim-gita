let s:V = gita#vital()
let s:MAPPING_TABLE = {
      \ '<Plug>(gita-apply)': 'Apply a patch to files and/or to the index',
      \}

function! gita#action#apply#action(candidates, ...) abort
  let options = extend({
        \}, get(a:000, 0, {}))
  let filenames = []
  for candidate in a:candidates
    if has_key(candidate, 'path')
      call add(filenames, get(candidate, 'path2', candidate.path))
    endif
  endfor
  if !empty(filenames)
    let result = gita#command#apply#call({
          \ 'quiet': 1,
          \ 'filenames': filenames,
          \})
  endif
endfunction

function! gita#action#apply#define_plugin_mappings() abort
  noremap <buffer><silent> <Plug>(gita-apply)
        \ :call gita#action#call('apply')<CR>
endfunction

function! gita#action#apply#define_default_mappings() abort
  map <buffer><nowait><expr> AA gita#action#smart_map('AA', '<Plug>(gita-apply)')
endfunction

function! gita#action#apply#get_mapping_table() abort
  return s:MAPPING_TABLE
endfunction

call gita#util#define_variables('action#apply', {})
