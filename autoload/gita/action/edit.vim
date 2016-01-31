let s:V = gita#vital()
let s:Path = s:V.import('System.Filepath')
let s:Anchor = s:V.import('Vim.Buffer.Anchor')
let s:MAPPING_TABLE = {
      \ '<Plug>(gita-edit)': 'Open for editing a content',
      \ '<Plug>(gita-edit-edit)': 'Open for editing a content in a window',
      \ '<Plug>(gita-edit-above)': 'Open for editing a content in an above window',
      \ '<Plug>(gita-edit-below)': 'Open for editing a content in a below window',
      \ '<Plug>(gita-edit-left)': 'Open for editing a content in a left window',
      \ '<Plug>(gita-edit-right)': 'Open for editing a content in a right window',
      \ '<Plug>(gita-edit-tabnew)': 'Open for editing a content in a new tab',
      \ '<Plug>(gita-edit-pedit)': 'Open for editing a content in a preview window',
      \}

function! gita#action#edit#action(candidates, ...) abort
  let options = extend({
        \ 'opener': g:gita#action#edit#default_opener,
        \ 'anchor': g:gita#action#edit#default_anchor,
        \}, get(a:000, 0, {}))
  if !empty(a:candidates) && options.anchor
    call s:Anchor.focus()
  endif
  for candidate in a:candidates
    if has_key(candidate, 'path')
      " NOTE:
      " 'path' or 'path2' is a real absolute path
      let bufname = get(candidate, 'path2', candidate.path)
      let bufname = expand(s:Path.relpath(bufname))
      call gita#util#buffer#open(bufname, {
            \ 'opener': options.opener,
            \})
    endif
  endfor
endfunction

function! gita#action#edit#define_plugin_mappings() abort
  noremap <buffer><silent> <Plug>(gita-edit)
        \ :call gita#action#call('edit')<CR>
  noremap <buffer><silent> <Plug>(gita-edit-edit)
        \ :call gita#action#call('edit', {'opener': 'edit', 'anchor': 1})<CR>
  noremap <buffer><silent> <Plug>(gita-edit-above)
        \ :call gita#action#call('edit', {'opener': 'leftabove new', 'anchor': 1})<CR>
  noremap <buffer><silent> <Plug>(gita-edit-below)
        \ :call gita#action#call('edit', {'opener': 'rightbelow new', 'anchor': 1})<CR>
  noremap <buffer><silent> <Plug>(gita-edit-left)
        \ :call gita#action#call('edit', {'opener': 'leftabove vnew', 'anchor': 1})<CR>
  noremap <buffer><silent> <Plug>(gita-edit-right)
        \ :call gita#action#call('edit', {'opener': 'rightbelow vnew', 'anchor': 1})<CR>
  noremap <buffer><silent> <Plug>(gita-edit-tabnew)
        \ :call gita#action#call('edit', {'opener': 'tabnew', 'anchor': 0})<CR>
  noremap <buffer><silent> <Plug>(gita-edit-pedit)
        \ :call gita#action#call('edit', {'opener': 'pedit', 'anchor': 0})<CR>
endfunction

function! gita#action#edit#define_default_mappings() abort
  map <buffer> ee <Plug>(gita-edit)
  map <buffer> EE <Plug>(gita-edit-right)
  map <buffer> et <Plug>(gita-edit-tabnew)
  map <buffer> ep <Plug>(gita-edit-pedit)
endfunction

function! gita#action#edit#get_mapping_table() abort
  return s:MAPPING_TABLE
endfunction

call gita#util#define_variables('action#edit', {
      \ 'default_opener': 'edit',
      \ 'default_anchor': 1,
      \})