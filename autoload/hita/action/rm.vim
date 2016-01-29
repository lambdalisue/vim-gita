let s:V = hita#vital()
let s:MAPPING_TABLE = {
      \ '<Plug>(hita-rm)': 'Add (rm) changes into an index',
      \ '<Plug>(hita-RM)': 'Add (rm) changes into an index (force)',
      \}

function! hita#action#rm#action(candidates, ...) abort
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
    let result = hita#command#rm#call({
          \ 'filenames': filenames,
          \ 'force': options.force,
          \ 'quiet': 1,
          \})
    " TODO: Show some success message?
  endif
endfunction

function! hita#action#rm#define_plugin_mappings() abort
  noremap <buffer><silent> <Plug>(hita-rm)
        \ :call hita#action#call('rm')<CR>
  noremap <buffer><silent> <Plug>(hita-RM)
        \ :call hita#action#call('rm', { 'force': 1 })<CR>
endfunction

function! hita#action#rm#define_default_mappings() abort
  map <buffer> -d <Plug>(hita-rm)
  map <buffer> -D <Plug>(hita-RM)
endfunction

function! hita#action#rm#get_mapping_table() abort
  return s:MAPPING_TABLE
endfunction

call hita#util#define_variables('action#rm', {})

