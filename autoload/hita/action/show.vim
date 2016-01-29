let s:V = hita#vital()
let s:Path = s:V.import('System.Filepath')
let s:Anchor = s:V.import('Vim.Buffer.Anchor')
let s:MAPPING_TABLE = {
      \ '<Plug>(hita-show)': 'Show an INDEX content',
      \ '<Plug>(hita-show-edit)': 'Show an INDEX content in a window',
      \ '<Plug>(hita-show-above)': 'Show an INDEX content in an above window',
      \ '<Plug>(hita-show-below)': 'Show an INDEX content in a below window',
      \ '<Plug>(hita-show-left)': 'Show an INDEX content in a left window',
      \ '<Plug>(hita-show-right)': 'Show an INDEX content in a right window',
      \ '<Plug>(hita-show-tabnew)': 'Show an INDEX content in a new tab',
      \ '<Plug>(hita-show-pedit)': 'Show an INDEX content in a preview window',
      \}

function! hita#action#show#action(candidates, ...) abort
  let options = extend({
        \ 'opener': g:hita#action#show#default_opener,
        \ 'anchor': g:hita#action#show#default_anchor,
        \}, get(a:000, 0, {}))
  if !empty(a:candidates) && options.anchor
    call s:Anchor.focus()
  endif
  for candidate in a:candidates
    if has_key(candidate, 'path')
      call hita#command#show#open({
            \ 'opener': options.opener,
            \ 'commit': get(options, 'commit', ''),
            \ 'filename': candidate.path,
            \})
    endif
  endfor
endfunction

function! hita#action#show#define_plugin_mappings() abort
  noremap <buffer><silent> <Plug>(hita-show)
        \ :call hita#action#call('show')<CR>
  noremap <buffer><silent> <Plug>(hita-show-edit)
        \ :call hita#action#call('show', {'opener': 'edit', 'anchor': 1})<CR>
  noremap <buffer><silent> <Plug>(hita-show-above)
        \ :call hita#action#call('show', {'opener': 'leftabove new', 'anchor': 1})<CR>
  noremap <buffer><silent> <Plug>(hita-show-below)
        \ :call hita#action#call('show', {'opener': 'rightbelow new', 'anchor': 1})<CR>
  noremap <buffer><silent> <Plug>(hita-show-left)
        \ :call hita#action#call('show', {'opener': 'leftabove vnew', 'anchor': 1})<CR>
  noremap <buffer><silent> <Plug>(hita-show-right)
        \ :call hita#action#call('show', {'opener': 'rightbelow vnew', 'anchor': 1})<CR>
  noremap <buffer><silent> <Plug>(hita-show-tabnew)
        \ :call hita#action#call('show', {'opener': 'tabnew', 'anchor': 0})<CR>
  noremap <buffer><silent> <Plug>(hita-show-pedit)
        \ :call hita#action#call('show', {'opener': 'pedit', 'anchor': 0})<CR>
endfunction

function! hita#action#show#define_default_mappings() abort
  map <buffer> oo <Plug>(hita-show)
  map <buffer> OO <Plug>(hita-show-right)
  map <buffer> ot <Plug>(hita-show-tabnew)
  map <buffer> op <Plug>(hita-show-pedit)
endfunction

function! hita#action#show#get_mapping_table() abort
  return s:MAPPING_TABLE
endfunction

call hita#util#define_variables('action#show', {
      \ 'default_opener': 'edit',
      \ 'default_anchor': 1,
      \})
