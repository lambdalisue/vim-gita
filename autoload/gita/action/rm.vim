let s:V = gita#vital()
let s:MAPPING_TABLE = {
      \ '<Plug>(gita-rm)': 'Remove files from the working tree and from the index',
      \ '<Plug>(gita-RM)': 'Remove files from the working tree and from the index (force)',
      \}

function! gita#action#rm#action(candidates, ...) abort
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
    let result = gita#command#rm#call({
          \ 'quiet': 1,
          \ 'filenames': filenames,
          \ 'force': options.force,
          \})
  endif
endfunction

function! gita#action#rm#define_plugin_mappings() abort
  noremap <buffer><silent> <Plug>(gita-rm)
        \ :call gita#action#call('rm')<CR>
  noremap <buffer><silent> <Plug>(gita-RM)
        \ :call gita#action#call('rm', { 'force': 1 })<CR>
endfunction

function! gita#action#rm#define_default_mappings() abort
  map <buffer><nowait><expr> -d gita#action#smart_map('-d', '<Plug>(gita-rm)')
  map <buffer><nowait><expr> -D gita#action#smart_map('-D', '<Plug>(gita-RM)')
endfunction

function! gita#action#rm#get_mapping_table() abort
  return s:MAPPING_TABLE
endfunction

call gita#util#define_variables('action#rm', {})

