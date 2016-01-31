let s:V = gita#vital()
let s:MAPPING_TABLE = {
      \ '<Plug>(gita-reset)': 'Reset changes on an index',
      \}

function! gita#action#reset#action(candidates, ...) abort
  let options = extend({
        \}, get(a:000, 0, {}))
  let filenames = []
  for candidate in a:candidates
    if has_key(candidate, 'path')
      call add(filenames, candidate.path)
    endif
  endfor
  if !empty(filenames)
    let result = gita#command#reset#call({
          \ 'filenames': filenames,
          \ 'quiet': 1,
          \})
    " TODO: Show some success mesage?
  endif
endfunction

function! gita#action#reset#define_plugin_mappings() abort
  noremap <buffer><silent> <Plug>(gita-reset)
        \ :call gita#action#call('reset')<CR>
endfunction

function! gita#action#reset#define_default_mappings() abort
  map <buffer> -r <Plug>(gita-reset)
endfunction

function! gita#action#reset#get_mapping_table() abort
  return s:MAPPING_TABLE
endfunction

call gita#util#define_variables('action#reset', {})
