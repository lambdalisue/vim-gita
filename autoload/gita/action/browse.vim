let s:V = gita#vital()
let s:Anchor = s:V.import('Vim.Buffer.Anchor')
let s:MAPPING_TABLE = {
      \ '<Plug>(gita-browse)': 'Browse a URL of a remote content',
      \ '<Plug>(gita-browse-diff)': 'Browse a (diff) URL of a remote content',
      \ '<Plug>(gita-browse-blame)': 'Browse a (blame) URL of a remote content',
      \ '<Plug>(gita-browse-exact)': 'Browse a (exact) URL of a remote content',
      \ '<Plug>(gita-browse-open)': 'Open a URL of a remote content',
      \ '<Plug>(gita-browse-echo)': 'Echo a URL of a remote content',
      \ '<Plug>(gita-browse-yank)': 'Yank a URL of a remote content',
      \}

function! s:is_available(candidate) abort
  let necessary_attributes = ['path']
  for attribute in necessary_attributes
    if !has_key(a:candidate, attribute)
      return 0
    endif
  endfor
  return 1
endfunction

function! gita#action#browse#action(candidates, ...) abort
  let options = extend({
        \ 'scheme': g:gita#action#browse#default_scheme,
        \ 'method': g:gita#action#browse#default_method,
        \}, get(a:000, 0, {}))
  call gita#option#assign_commit(options)
  call gita#option#assign_selection(options)
  for candidate in a:candidates
    if has_key(candidate, 'path')
      call gita#command#browse#{options.method}({
            \ 'scheme': options.scheme,
            \ 'commit': get(options, 'commit', ''),
            \ 'selection': get(options, 'selection', []),
            \ 'filename': candidate.path,
            \})
    endif
  endfor
endfunction

function! gita#action#browse#define_plugin_mappings() abort
  noremap <buffer><silent> <Plug>(gita-browse)
        \ :call gita#action#call('browse')<CR>
  noremap <buffer><silent> <Plug>(gita-browse-diff)
        \ :call gita#action#call('browse', {'scheme': 'diff'})<CR>
  noremap <buffer><silent> <Plug>(gita-browse-blame)
        \ :call gita#action#call('browse', {'scheme': 'blame'})<CR>
  noremap <buffer><silent> <Plug>(gita-browse-exact)
        \ :call gita#action#call('browse', {'scheme': 'exact'})<CR>
  noremap <buffer><silent> <Plug>(gita-browse-open)
        \ :call gita#action#call('browse', {'method': 'open'})<CR>
  noremap <buffer><silent> <Plug>(gita-browse-echo)
        \ :call gita#action#call('browse', {'method': 'echo'})<CR>
  noremap <buffer><silent> <Plug>(gita-browse-yank)
        \ :call gita#action#call('browse', {'method': 'yank'})<CR>
endfunction

function! gita#action#browse#define_default_mappings() abort
  map <buffer><nowait><expr> bb gita#action#smart_map('bb', '<Plug>(gita-browse)')
  map <buffer><nowait><expr> bd gita#action#smart_map('bd', '<Plug>(gita-browse-diff)')
  map <buffer><nowait><expr> bB gita#action#smart_map('bB', '<Plug>(gita-browse-blame)')
  map <buffer><nowait><expr> be gita#action#smart_map('be', '<Plug>(gita-browse-exact)')
  map <buffer><nowait><expr> yy gita#action#smart_map('yy', '<Plug>(gita-browse-yank)')
endfunction

function! gita#action#browse#get_mapping_table() abort
  return s:MAPPING_TABLE
endfunction

call gita#util#define_variables('action#browse', {
      \ 'default_scheme': '_',
      \ 'default_method': 'open',
      \})
