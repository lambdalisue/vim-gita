let s:V = gita#vital()
let s:Anchor = s:V.import('Vim.Buffer.Anchor')
let s:MAPPING_TABLE = {
      \ '<Plug>(gita-add)': 'Add changes into an index',
      \ '<Plug>(gita-ADD)': 'Add changes into an index (force)',
      \ '<Plug>(gita-add-p)': 'Add changes into an index with PATCH mode',
      \}

function! gita#action#add#action(candidates, ...) abort
  let options = extend({
        \ 'force': 0,
        \ 'patch': 0,
        \}, get(a:000, 0, {}))
  let filenames = []
  for candidate in a:candidates
    if has_key(candidate, 'path')
      call add(filenames, get(candidate, 'path2', candidate.path))
    endif
  endfor
  if !empty(filenames)
    if options.patch
      call s:Anchor.focus()
      let result = gita#command#add#patch({
            \ 'filenames': filenames,
            \ 'patch': options.patch,
            \})
    else
      let result = gita#command#add#call({
            \ 'filenames': filenames,
            \ 'force': options.force,
            \ 'patch': options.patch,
            \ 'ignore-errors': 1,
            \})
    endif
    " TODO: Show some success message?
  endif
endfunction

function! gita#action#add#define_plugin_mappings() abort
  noremap <buffer><silent> <Plug>(gita-add)
        \ :call gita#action#call('add')<CR>
  noremap <buffer><silent> <Plug>(gita-ADD)
        \ :call gita#action#call('add', { 'force': 1 })<CR>
  nnoremap <buffer><silent> <Plug>(gita-add-p)
        \ :<C-u>call gita#action#call('add', { 'patch': 1 })<CR>
endfunction

function! gita#action#add#define_default_mappings() abort
  map <buffer><nowait><expr> -a gita#action#smart_map('-a', '<Plug>(gita-add)')
  map <buffer><nowait><expr> -A gita#action#smart_map('-A', '<Plug>(gita-ADD)')
  nmap <buffer><nowait><expr> -p gita#action#smart_map('-p', '<Plug>(gita-add-p)')
endfunction

function! gita#action#add#get_mapping_table() abort
  return s:MAPPING_TABLE
endfunction

call gita#util#define_variables('action#add', {})
