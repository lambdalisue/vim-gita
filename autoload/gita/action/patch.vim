let s:V = gita#vital()
let s:MAPPING_TABLE = {
      \ '<Plug>(gita-patch)':   'Patch file contents to the index',
      \ '<Plug>(gita-patch-1)': 'Patch file contents to the index (one way)',
      \ '<Plug>(gita-patch-2)': 'Patch file contents to the index (two way)',
      \ '<Plug>(gita-patch-3)': 'Patch file contents to the index (three way)',
      \}

function! gita#action#patch#action(candidates, ...) abort
  let options = extend({
        \ 'anchor': 1,
        \ 'method': g:gita#action#patch#default_method,
        \ 'opener': g:gita#action#patch#default_opener,
        \}, get(a:000, 0, {}))
  call gita#option#assign_selection(options)
  for candidate in a:candidates
    if has_key(candidate, 'path')
      call gita#command#patch#open({
            \ 'method': options.method,
            \ 'anchor': options.anchor,
            \ 'opener': options.opener,
            \ 'selection': get(candidate, 'selection', get(options, 'selection', [])),
            \ 'filename': candidate.path,
            \})
    endif
  endfor
endfunction

function! gita#action#patch#define_plugin_mappings() abort
  nnoremap <buffer><silent> <Plug>(gita-patch)
        \ :call gita#action#call('patch')<CR>
  nnoremap <buffer><silent> <Plug>(gita-patch-1)
        \ :call gita#action#call('patch', { 'method': 'one' })<CR>
  nnoremap <buffer><silent> <Plug>(gita-patch-2)
        \ :call gita#action#call('patch', { 'method': 'two' })<CR>
  nnoremap <buffer><silent> <Plug>(gita-patch-3)
        \ :call gita#action#call('patch', { 'method': 'three' })<CR>
endfunction

function! gita#action#patch#define_default_mappings() abort
  nmap <buffer><nowait><expr> pp gita#action#smart_map('pp', '<Plug>(gita-patch)')
  nmap <buffer><nowait><expr> p1 gita#action#smart_map('p1', '<Plug>(gita-patch-1)')
  nmap <buffer><nowait><expr> p2 gita#action#smart_map('p2', '<Plug>(gita-patch-2)')
  nmap <buffer><nowait><expr> p3 gita#action#smart_map('p3', '<Plug>(gita-patch-3)')
endfunction

function! gita#action#patch#get_mapping_table() abort
  return s:MAPPING_TABLE
endfunction

call gita#util#define_variables('action#patch', {
      \ 'default_method': '',
      \ 'default_opener': '',
      \})
