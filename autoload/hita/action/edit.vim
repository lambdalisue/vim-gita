let s:V = hita#vital()
let s:Path = s:V.import('System.Filepath')
let s:Anchor = s:V.import('Vim.Buffer.Anchor')
let s:MAPPING_TABLE = {
      \ '<Plug>(hita-edit)': 'Open for editing a content',
      \ '<Plug>(hita-edit-edit)': 'Open for editing a content in a window',
      \ '<Plug>(hita-edit-above)': 'Open for editing a content in an above window',
      \ '<Plug>(hita-edit-below)': 'Open for editing a content in a below window',
      \ '<Plug>(hita-edit-left)': 'Open for editing a content in a left window',
      \ '<Plug>(hita-edit-right)': 'Open for editing a content in a right window',
      \ '<Plug>(hita-edit-tabnew)': 'Open for editing a content in a new tab',
      \ '<Plug>(hita-edit-pedit)': 'Open for editing a content in a preview window',
      \}

function! hita#action#edit#action(candidates, ...) abort
  let options = extend({
        \ 'opener': g:hita#action#edit#default_opener,
        \ 'anchor': g:hita#action#edit#default_anchor,
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
      call hita#util#buffer#open(bufname, {
            \ 'opener': options.opener,
            \})
    endif
  endfor
endfunction

function! hita#action#edit#define_plugin_mappings() abort
  noremap <buffer><silent> <Plug>(hita-edit)
        \ :call hita#action#call('edit')<CR>
  noremap <buffer><silent> <Plug>(hita-edit-edit)
        \ :call hita#action#call('edit', {'opener': 'edit', 'anchor': 1})<CR>
  noremap <buffer><silent> <Plug>(hita-edit-above)
        \ :call hita#action#call('edit', {'opener': 'leftabove new', 'anchor': 1})<CR>
  noremap <buffer><silent> <Plug>(hita-edit-below)
        \ :call hita#action#call('edit', {'opener': 'rightbelow new', 'anchor': 1})<CR>
  noremap <buffer><silent> <Plug>(hita-edit-left)
        \ :call hita#action#call('edit', {'opener': 'leftabove vnew', 'anchor': 1})<CR>
  noremap <buffer><silent> <Plug>(hita-edit-right)
        \ :call hita#action#call('edit', {'opener': 'rightbelow vnew', 'anchor': 1})<CR>
  noremap <buffer><silent> <Plug>(hita-edit-tabnew)
        \ :call hita#action#call('edit', {'opener': 'tabnew', 'anchor': 0})<CR>
  noremap <buffer><silent> <Plug>(hita-edit-pedit)
        \ :call hita#action#call('edit', {'opener': 'pedit', 'anchor': 0})<CR>
endfunction

function! hita#action#edit#define_default_mappings() abort
  map <buffer> ee <Plug>(hita-edit)
  map <buffer> EE <Plug>(hita-edit-right)
  map <buffer> et <Plug>(hita-edit-tabnew)
  map <buffer> ep <Plug>(hita-edit-pedit)
endfunction

function! hita#action#edit#get_mapping_table() abort
  return s:MAPPING_TABLE
endfunction

call hita#util#define_variables('action#edit', {
      \ 'default_opener': 'edit',
      \ 'default_anchor': 1,
      \})