let s:V = hita#vital()
let s:MAPPING_TABLE = {
      \ '<Plug>(hita-add)': 'Add changes into an index',
      \ '<Plug>(hita-ADD)': 'Add changes into an index (force)',
      \}

function! hita#action#add#action(candidates, ...) abort
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
    let result = hita#command#add#call({
          \ 'filenames': filenames,
          \ 'force': options.force,
          \ 'ignore-errors': 1,
          \})
    " TODO: Show some success message?
  endif
endfunction

function! hita#action#add#define_plugin_mappings() abort
  noremap <buffer><silent> <Plug>(hita-add)
        \ :call hita#action#call('add')<CR>
  noremap <buffer><silent> <Plug>(hita-ADD)
        \ :call hita#action#call('add', { 'force': 1 })<CR>
endfunction

function! hita#action#add#define_default_mappings() abort
  map <buffer> -a <Plug>(hita-add)
  map <buffer> -A <Plug>(hita-ADD)
endfunction

function! hita#action#add#get_mapping_table() abort
  return s:MAPPING_TABLE
endfunction

call hita#util#define_variables('action#add', {})
