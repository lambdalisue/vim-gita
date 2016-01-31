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
  let candidates = filter(copy(a:candidates), 's:is_available(v:val)')
  let filenames = map(candidates, 'v:val.path')
  call gita#command#browse#{options.method}({
        \ 'scheme': options.scheme,
        \ 'commit': get(options, 'commit', ''),
        \ 'filenames': filenames,
        \})
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
  map <buffer> bb <Plug>(gita-browse)
  map <buffer> bd <Plug>(gita-browse-diff)
  map <buffer> bB <Plug>(gita-browse-blame)
  map <buffer> be <Plug>(gita-browse-exact)
  map <buffer> yy <Plug>(gita-browse-yank)
endfunction

function! gita#action#browse#get_mapping_table() abort
  return s:MAPPING_TABLE
endfunction

call gita#util#define_variables('action#browse', {
      \ 'default_scheme': '_',
      \ 'default_method': 'open',
      \})
