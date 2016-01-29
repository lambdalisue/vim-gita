let s:V = hita#vital()
let s:Anchor = s:V.import('Vim.Buffer.Anchor')
let s:MAPPING_TABLE = {
      \ '<Plug>(hita-blame)': 'Blame a content',
      \}

function! hita#action#blame#action(candidates, ...) abort
  let options = extend({
        \ 'opener': g:hita#action#blame#default_opener,
        \ 'anchor': g:hita#action#blame#default_anchor,
        \}, get(a:000, 0, {}))
  if !empty(a:candidates) && options.anchor
    call s:Anchor.focus()
  endif
  for candidate in a:candidates
    if has_key(candidate, 'path')
      call hita#command#blame#open({
            \ 'opener': options.opener,
            \ 'commit': get(options, 'commit', ''),
            \ 'filename': candidate.path,
            \})
    endif
  endfor
endfunction

function! hita#action#blame#define_plugin_mappings() abort
  noremap <buffer><silent> <Plug>(hita-blame)
        \ :call hita#action#call('blame')<CR>
endfunction

function! hita#action#blame#define_default_mappings() abort
  map <buffer> BB <Plug>(hita-blame)
endfunction

function! hita#action#blame#get_mapping_table() abort
  return s:MAPPING_TABLE
endfunction

call hita#util#define_variables('apply#blame', {
      \ 'default_opener': 'tabnew',
      \ 'default_anchor': 0,
      \})
