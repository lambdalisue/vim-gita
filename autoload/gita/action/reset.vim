let s:V = gita#vital()
let s:Anchor = s:V.import('Vim.Buffer.Anchor')
let s:MAPPING_TABLE = {
      \ '<Plug>(gita-reset)': 'Reset changes on an index',
      \ '<Plug>(gita-reset-p)': 'Reset changes on an index with PATCH mode',
      \}

function! gita#action#reset#action(candidates, ...) abort
  let options = extend({
        \ 'patch': 0,
        \}, get(a:000, 0, {}))
  call gita#option#assign_commit(options)
  let filenames = []
  for candidate in a:candidates
    if has_key(candidate, 'path')
      call add(filenames, candidate.path)
    endif
  endfor
  if !empty(filenames)
    if options.patch
      call s:Anchor.focus()
      let result = gita#command#reset#patch({
            \ 'filenames': filenames,
            \ 'patch': options.patch,
            \})
    else
      let result = gita#command#reset#call({
            \ 'commit': get(options, 'commit', ''),
            \ 'filenames': filenames,
            \ 'patch': options.patch,
            \ 'quiet': 1,
            \})
    endif
    " TODO: Show some success mesage?
  endif
endfunction

function! gita#action#reset#define_plugin_mappings() abort
  noremap <buffer><silent> <Plug>(gita-reset)
        \ :call gita#action#call('reset')<CR>
  nnoremap <buffer><silent> <Plug>(gita-reset-p)
        \ :<C-u>call gita#action#call('reset', { 'patch': 1 })<CR>
endfunction

function! gita#action#reset#define_default_mappings() abort
  map <buffer><nowait><expr> -r gita#action#smart_map('-r', '<Plug>(gita-reset)')
  nmap <buffer><nowait><expr> -P gita#action#smart_map('-P', '<Plug>(gita-reset-p)')
endfunction

function! gita#action#reset#get_mapping_table() abort
  return s:MAPPING_TABLE
endfunction

call gita#util#define_variables('action#reset', {})
