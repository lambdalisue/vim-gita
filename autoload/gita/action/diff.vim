let s:V = gita#vital()
let s:MAPPING_TABLE = {
      \ '<Plug>(gita-diff)': 'Diff an (INDEX) content',
      \ '<Plug>(gita-diff-edit)': 'Diff an (INDEX) content in a window',
      \ '<Plug>(gita-diff-above)': 'Diff an (INDEX) content in an above window',
      \ '<Plug>(gita-diff-below)': 'Diff an (INDEX) content in a below window',
      \ '<Plug>(gita-diff-left)': 'Diff an (INDEX) content in a left window',
      \ '<Plug>(gita-diff-right)': 'Diff an (INDEX) content in a right window',
      \ '<Plug>(gita-diff-tabnew)': 'Diff an (INDEX) content in a new tab',
      \ '<Plug>(gita-diff-pedit)': 'Diff an (INDEX) content in a preview window',
      \ '<Plug>(gita-diff-vertical)': 'Diff an (INDEX) content in two window (vertical)',
      \ '<Plug>(gita-diff-horizontal)': 'Diff an (INDEX) content in two window (horizontal)',
      \}

function! gita#action#diff#action(candidates, ...) abort
  let options = extend({
        \ 'opener': g:gita#action#diff#default_opener,
        \ 'anchor': g:gita#action#diff#default_anchor,
        \ 'split': g:gita#action#diff#default_split,
        \}, get(a:000, 0, {}))
  call gita#option#assign_commit(options)
  call gita#option#assign_selection(options)
  for candidate in a:candidates
    if has_key(candidate, 'path')
      if empty(options.split)
        call gita#command#diff#open({
              \ 'anchor': options.anchor,
              \ 'opener': options.opener,
              \ 'selection': get(options, 'selection', []),
              \ 'cached': !get(candidate, 'is_unstaged', 1),
              \ 'commit': get(options, 'commit', ''),
              \ 'filename': candidate.path,
              \})
      else
        call gita#command#diff#open2({
              \ 'anchor': options.anchor,
              \ 'opener': options.opener,
              \ 'selection': get(options, 'selection', []),
              \ 'split': options.split,
              \ 'cached': !get(candidate, 'is_unstaged', 1),
              \ 'commit': get(options, 'commit', ''),
              \ 'filename': candidate.path,
              \})
      endif
    endif
  endfor
endfunction

function! gita#action#diff#define_plugin_mappings() abort
  noremap <buffer><silent> <Plug>(gita-diff)
        \ :call gita#action#call('diff')<CR>
  noremap <buffer><silent> <Plug>(gita-diff-edit)
        \ :call gita#action#call('diff', {'opener': 'edit', 'anchor': 1, 'split': ''})<CR>
  noremap <buffer><silent> <Plug>(gita-diff-above)
        \ :call gita#action#call('diff', {'opener': 'leftabove new', 'anchor': 1, 'split': ''})<CR>
  noremap <buffer><silent> <Plug>(gita-diff-below)
        \ :call gita#action#call('diff', {'opener': 'rightbelow new', 'anchor': 1, 'split': ''})<CR>
  noremap <buffer><silent> <Plug>(gita-diff-left)
        \ :call gita#action#call('diff', {'opener': 'leftabove vnew', 'anchor': 1, 'split': ''})<CR>
  noremap <buffer><silent> <Plug>(gita-diff-right)
        \ :call gita#action#call('diff', {'opener': 'rightbelow vnew', 'anchor': 1, 'split': ''})<CR>
  noremap <buffer><silent> <Plug>(gita-diff-tabnew)
        \ :call gita#action#call('diff', {'opener': 'tabnew', 'anchor': 0, 'split': ''})<CR>
  noremap <buffer><silent> <Plug>(gita-diff-pedit)
        \ :call gita#action#call('diff', {'opener': 'pedit', 'anchor': 0, 'split': ''})<CR>
  noremap <buffer><silent> <Plug>(gita-diff-vertical)
        \ :call gita#action#call('diff', {'opener': 'edit', 'anchor': 1, 'split': 'vertical'})<CR>
  noremap <buffer><silent> <Plug>(gita-diff-horizontal)
        \ :call gita#action#call('diff', {'opener': 'edit', 'anchor': 1, 'split': 'horizontal'})<CR>
endfunction

function! gita#action#diff#define_default_mappings() abort
  map <buffer><nowait><expr> dd gita#action#smart_map('dd', '<Plug>(gita-diff)')
  map <buffer><nowait><expr> DD gita#action#smart_map('DD', '<Plug>(gita-diff-right)')
  map <buffer><nowait><expr> dt gita#action#smart_map('dt', '<Plug>(gita-diff-tabnew)')
  map <buffer><nowait><expr> dp gita#action#smart_map('dp', '<Plug>(gita-diff-pedit)')
  map <buffer><nowait><expr> ds gita#action#smart_map('ds', '<Plug>(gita-diff-vertical)')
  map <buffer><nowait><expr> DS gita#action#smart_map('DS', '<Plug>(gita-diff-horizontal)')
endfunction

function! gita#action#diff#get_mapping_table() abort
  return s:MAPPING_TABLE
endfunction

call gita#util#define_variables('action#diff', {
      \ 'default_opener': 'edit',
      \ 'default_anchor': 1,
      \ 'default_split': '',
      \})
