let s:V = gita#vital()
let s:Anchor = s:V.import('Vim.Buffer.Anchor')
let s:MAPPING_TABLE = {
      \ '<Plug>(gita-blame)': 'Blame a content',
      \}

function! gita#action#blame#action(candidates, ...) abort
  let options = extend({
        \ 'opener': g:gita#action#blame#default_opener,
        \ 'anchor': g:gita#action#blame#default_anchor,
        \}, get(a:000, 0, {}))
  if !empty(a:candidates) && options.anchor
    call s:Anchor.focus()
  endif
  for candidate in a:candidates
    if has_key(candidate, 'path')
      call gita#command#blame#open({
            \ 'opener': options.opener,
            \ 'commit': get(options, 'commit', ''),
            \ 'filename': candidate.path,
            \})
    endif
  endfor
endfunction

function! gita#action#blame#define_plugin_mappings() abort
  noremap <buffer><silent> <Plug>(gita-blame)
        \ :call gita#action#call('blame')<CR>
endfunction

function! gita#action#blame#define_default_mappings() abort
  map <buffer> BB <Plug>(gita-blame)
endfunction

function! gita#action#blame#get_mapping_table() abort
  return s:MAPPING_TABLE
endfunction

call gita#util#define_variables('apply#blame', {
      \ 'default_opener': 'tabnew',
      \ 'default_anchor': 0,
      \})
