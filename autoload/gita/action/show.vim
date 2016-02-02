let s:V = gita#vital()
let s:MAPPING_TABLE = {
      \ '<Plug>(gita-show)': 'Show an INDEX content',
      \ '<Plug>(gita-show-edit)': 'Show an INDEX content in a window',
      \ '<Plug>(gita-show-above)': 'Show an INDEX content in an above window',
      \ '<Plug>(gita-show-below)': 'Show an INDEX content in a below window',
      \ '<Plug>(gita-show-left)': 'Show an INDEX content in a left window',
      \ '<Plug>(gita-show-right)': 'Show an INDEX content in a right window',
      \ '<Plug>(gita-show-tabnew)': 'Show an INDEX content in a new tab',
      \ '<Plug>(gita-show-pedit)': 'Show an INDEX content in a preview window',
      \}

function! gita#action#show#action(candidates, ...) abort
  let options = extend({
        \ 'opener': g:gita#action#show#default_opener,
        \ 'anchor': g:gita#action#show#default_anchor,
        \}, get(a:000, 0, {}))
  call gita#option#assign_commit(options)
  call gita#option#assign_selection(options)
  for candidate in a:candidates
    if has_key(candidate, 'path')
      call gita#command#show#open({
            \ 'anchor': options.anchor,
            \ 'opener': options.opener,
            \ 'selection': get(options, 'selection', []),
            \ 'commit': get(options, 'commit', ''),
            \ 'filename': candidate.path,
            \})
    endif
  endfor
endfunction

function! gita#action#show#define_plugin_mappings() abort
  noremap <buffer><silent> <Plug>(gita-show)
        \ :call gita#action#call('show')<CR>
  noremap <buffer><silent> <Plug>(gita-show-edit)
        \ :call gita#action#call('show', {'opener': 'edit', 'anchor': 1})<CR>
  noremap <buffer><silent> <Plug>(gita-show-above)
        \ :call gita#action#call('show', {'opener': 'leftabove new', 'anchor': 1})<CR>
  noremap <buffer><silent> <Plug>(gita-show-below)
        \ :call gita#action#call('show', {'opener': 'rightbelow new', 'anchor': 1})<CR>
  noremap <buffer><silent> <Plug>(gita-show-left)
        \ :call gita#action#call('show', {'opener': 'leftabove vnew', 'anchor': 1})<CR>
  noremap <buffer><silent> <Plug>(gita-show-right)
        \ :call gita#action#call('show', {'opener': 'rightbelow vnew', 'anchor': 1})<CR>
  noremap <buffer><silent> <Plug>(gita-show-tabnew)
        \ :call gita#action#call('show', {'opener': 'tabnew', 'anchor': 0})<CR>
  noremap <buffer><silent> <Plug>(gita-show-pedit)
        \ :call gita#action#call('show', {'opener': 'pedit', 'anchor': 0})<CR>
endfunction

function! gita#action#show#define_default_mappings() abort
  map <buffer><nowait><expr> ss gita#action#smart_map('ss', '<Plug>(gita-show)')
  map <buffer><nowait><expr> SS gita#action#smart_map('SS', '<Plug>(gita-show-right)')
  map <buffer><nowait><expr> st gita#action#smart_map('st', '<Plug>(gita-show-tabnew)')
  map <buffer><nowait><expr> sp gita#action#smart_map('sp', '<Plug>(gita-show-pedit)')
endfunction

function! gita#action#show#get_mapping_table() abort
  return s:MAPPING_TABLE
endfunction

call gita#util#define_variables('action#show', {
      \ 'default_opener': '',
      \ 'default_anchor': 1,
      \})
