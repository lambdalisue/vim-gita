let s:V = gita#vital()
let s:MAPPING_TABLE = {
      \ '<Plug>(gita-commit)': 'Open gita-commit window',
      \ '<Plug>(gita-commit-new)': 'Open gita-commit window in new mode',
      \ '<Plug>(gita-commit-amend)': 'Open gita-commit window in amend mode',
      \}

function! gita#action#commit#action(candidates, ...) abort
  let options = extend({
        \ 'amend': -1,
        \}, get(a:000, 0, {}))
  let filenames = gita#get_meta('filenames', [])
  if options.amend == -1
    call gita#command#commit#open({
          \ 'filenames': filenames,
          \})
  else
    call gita#command#commit#open({
          \ 'amend': options.amend,
          \ 'filenames': filenames,
          \})
  endif
endfunction

function! gita#action#commit#define_plugin_mappings() abort
  noremap <buffer><silent> <Plug>(gita-commit)
        \ :<C-u>call gita#action#call('commit')<CR>
  noremap <buffer><silent> <Plug>(gita-commit-new)
        \ :<C-u>call gita#action#call('commit', { 'amend': 0 })<CR>
  noremap <buffer><silent> <Plug>(gita-commit-amend)
        \ :<C-u>call gita#action#call('commit', { 'amend': 1 })<CR>
endfunction

function! gita#action#commit#define_default_mappings() abort
  nmap <buffer> cc <Plug>(gita-commit)
  nmap <buffer> cC <Plug>(gita-commit-new)
  nmap <buffer> cA <Plug>(gita-commit-amend)
endfunction

function! gita#action#commit#get_mapping_table() abort
  return s:MAPPING_TABLE
endfunction

call gita#util#define_variables('action#commit', {})


