let s:V = hita#vital()
let s:MAPPING_TABLE = {
      \ '<Plug>(hita-apply)': 'Apply diff into an index',
      \}

function! hita#action#apply#action(candidates, ...) abort
  let options = extend({
        \}, get(a:000, 0, {}))
  let filenames = []
  for candidate in a:candidates
    if has_key(candidate, 'path')
      call add(filenames, get(candidate, 'path2', candidate.path))
    endif
  endfor
  if !empty(filenames)
    let result = hita#command#apply#call({
          \ 'filenames': filenames,
          \})
    " TODO: Show some success message?
  endif
endfunction

function! hita#action#apply#define_plugin_mappings() abort
  noremap <buffer><silent> <Plug>(hita-apply)
        \ :call hita#action#call('apply')<CR>
endfunction

function! hita#action#apply#define_default_mappings() abort
  map <buffer> AA <Plug>(hita-apply)
endfunction

function! hita#action#apply#get_mapping_table() abort
  return s:MAPPING_TABLE
endfunction

call hita#util#define_variables('action#apply', {})

