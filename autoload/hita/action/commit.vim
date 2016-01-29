let s:V = hita#vital()
let s:MAPPING_TABLE = {
      \ '<Plug>(hita-commit)': 'Open hita-commit window',
      \ '<Plug>(hita-commit-new)': 'Open hita-commit window in new mode',
      \ '<Plug>(hita-commit-amend)': 'Open hita-commit window in amend mode',
      \}

function! hita#action#commit#action(candidates, ...) abort
  let options = extend({
        \ 'amend': -1,
        \}, get(a:000, 0, {}))
  let filenames = hita#get_meta('filenames', [])
  if options.amend == -1
    call hita#command#commit#open({
          \ 'filenames': filenames,
          \})
  else
    call hita#command#commit#open({
          \ 'amend': options.amend,
          \ 'filenames': filenames,
          \})
  endif
endfunction

function! hita#action#commit#define_plugin_mappings() abort
  noremap <buffer><silent> <Plug>(hita-commit)
        \ :call hita#action#call('commit')<CR>
  noremap <buffer><silent> <Plug>(hita-commit-new)
        \ :call hita#action#call('commit', { 'amend': 0 })<CR>
  noremap <buffer><silent> <Plug>(hita-commit-amend)
        \ :call hita#action#call('commit', { 'amend': 1 })<CR>
endfunction

function! hita#action#commit#define_default_mappings() abort
  map <buffer> cc <Plug>(hita-commit)
  map <buffer> cC <Plug>(hita-commit-new)
  map <buffer> cA <Plug>(hita-commit-amend)
endfunction

function! hita#action#commit#get_mapping_table() abort
  return s:MAPPING_TABLE
endfunction

call hita#util#define_variables('action#commit', {})


