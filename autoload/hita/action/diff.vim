let s:V = hita#vital()
let s:Anchor = s:V.import('Vim.Buffer.Anchor')
let s:MAPPING_TABLE = {
      \ '<Plug>(hita-diff)': 'Diff an (INDEX) content',
      \ '<Plug>(hita-diff-edit)': 'Diff an (INDEX) content in a window',
      \ '<Plug>(hita-diff-above)': 'Diff an (INDEX) content in an above window',
      \ '<Plug>(hita-diff-below)': 'Diff an (INDEX) content in a below window',
      \ '<Plug>(hita-diff-left)': 'Diff an (INDEX) content in a left window',
      \ '<Plug>(hita-diff-right)': 'Diff an (INDEX) content in a right window',
      \ '<Plug>(hita-diff-tabnew)': 'Diff an (INDEX) content in a new tab',
      \ '<Plug>(hita-diff-pedit)': 'Diff an (INDEX) content in a preview window',
      \ '<Plug>(hita-diff-vertical)': 'Diff an (INDEX) content in two window (vertical)',
      \ '<Plug>(hita-diff-horizontal)': 'Diff an (INDEX) content in two window (horizontal)',
      \}

function! hita#action#diff#action(candidates, ...) abort
  let options = extend({
        \ 'opener': g:hita#action#diff#default_opener,
        \ 'anchor': g:hita#action#diff#default_anchor,
        \ 'split': g:hita#action#diff#default_split,
        \}, get(a:000, 0, {}))
  if !empty(a:candidates) && options.anchor
    call s:Anchor.focus()
  endif
  for candidate in a:candidates
    if has_key(candidate, 'path')
      if empty(options.split)
        call hita#command#diff#open({
              \ 'opener': options.opener,
              \ 'commit': get(options, 'commit', ''),
              \ 'cached': !get(candidate, 'is_unstaged', 1),
              \ 'filenames': [candidate.path],
              \})
      else
        call hita#command#diff#open2({
              \ 'opener': options.opener,
              \ 'split': options.split,
              \ 'commit': get(options, 'commit', ''),
              \ 'cached': !get(candidate, 'is_unstaged', 1),
              \ 'filenames': [candidate.path],
              \})
      endif
    endif
  endfor
endfunction

function! hita#action#diff#define_plugin_mappings() abort
  noremap <buffer><silent> <Plug>(hita-diff)
        \ :call hita#action#call('diff')<CR>
  noremap <buffer><silent> <Plug>(hita-diff-edit)
        \ :call hita#action#call('diff', {'opener': 'edit', 'anchor': 1, 'split': ''})<CR>
  noremap <buffer><silent> <Plug>(hita-diff-above)
        \ :call hita#action#call('diff', {'opener': 'leftabove new', 'anchor': 1, 'split': ''})<CR>
  noremap <buffer><silent> <Plug>(hita-diff-below)
        \ :call hita#action#call('diff', {'opener': 'rightbelow new', 'anchor': 1, 'split': ''})<CR>
  noremap <buffer><silent> <Plug>(hita-diff-left)
        \ :call hita#action#call('diff', {'opener': 'leftabove vnew', 'anchor': 1, 'split': ''})<CR>
  noremap <buffer><silent> <Plug>(hita-diff-right)
        \ :call hita#action#call('diff', {'opener': 'rightbelow vnew', 'anchor': 1, 'split': ''})<CR>
  noremap <buffer><silent> <Plug>(hita-diff-tabnew)
        \ :call hita#action#call('diff', {'opener': 'tabnew', 'anchor': 0, 'split': ''})<CR>
  noremap <buffer><silent> <Plug>(hita-diff-pedit)
        \ :call hita#action#call('diff', {'opener': 'pedit', 'anchor': 0, 'split': ''})<CR>
  noremap <buffer><silent> <Plug>(hita-diff-vertical)
        \ :call hita#action#call('diff', {'opener': 'edit', 'anchor': 1, 'split': 'vertical'})<CR>
  noremap <buffer><silent> <Plug>(hita-diff-horizontal)
        \ :call hita#action#call('diff', {'opener': 'edit', 'anchor': 1, 'split': 'horizontal'})<CR>
endfunction

function! hita#action#diff#define_default_mappings() abort
  map <buffer> dd <Plug>(hita-diff)
  map <buffer> DD <Plug>(hita-diff-right)
  map <buffer> dt <Plug>(hita-diff-tabnew)
  map <buffer> dp <Plug>(hita-diff-pedit)
  map <buffer> ss <Plug>(hita-diff-vertical)
  map <buffer> SS <Plug>(hita-diff-horizontal)
endfunction

function! hita#action#diff#get_mapping_table() abort
  return s:MAPPING_TABLE
endfunction

call hita#util#define_variables('action#diff', {
      \ 'default_opener': 'edit',
      \ 'default_anchor': 1,
      \ 'default_split': '',
      \})
