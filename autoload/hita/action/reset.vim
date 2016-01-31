let s:V = hita#vital()
let s:MAPPING_TABLE = {
      \ '<Plug>(hita-reset)': 'Reset changes on an index',
      \}

function! hita#action#reset#action(candidates, ...) abort
  let options = extend({
        \}, get(a:000, 0, {}))
  let filenames = []
  for candidate in a:candidates
    if has_key(candidate, 'path')
      call add(filenames, candidate.path)
    endif
  endfor
  if !empty(filenames)
    let result = hita#command#reset#call({
          \ 'filenames': filenames,
          \ 'quiet': 1,
          \})
    " TODO: Show some success mesage?
  endif
endfunction

function! hita#action#reset#define_plugin_mappings() abort
  noremap <buffer><silent> <Plug>(hita-reset)
        \ :call hita#action#call('reset')<CR>
endfunction

function! hita#action#reset#define_default_mappings() abort
  map <buffer> -r <Plug>(hita-reset)
endfunction

function! hita#action#reset#get_mapping_table() abort
  return s:MAPPING_TABLE
endfunction

call hita#util#define_variables('action#reset', {})
