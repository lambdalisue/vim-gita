let s:V = hita#vital()
let s:Anchor = s:V.import('Vim.Buffer.Anchor')
let s:MAPPING_TABLE = {
      \ '<Plug>(hita-browse)': 'Browse a URL of a remote content',
      \ '<Plug>(hita-browse-diff)': 'Browse a (diff) URL of a remote content',
      \ '<Plug>(hita-browse-blame)': 'Browse a (blame) URL of a remote content',
      \ '<Plug>(hita-browse-exact)': 'Browse a (exact) URL of a remote content',
      \ '<Plug>(hita-browse-open)': 'Open a URL of a remote content',
      \ '<Plug>(hita-browse-echo)': 'Echo a URL of a remote content',
      \ '<Plug>(hita-browse-yank)': 'Yank a URL of a remote content',
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

function! hita#action#browse#action(candidates, ...) abort
  let options = extend({
        \ 'scheme': g:hita#action#browse#default_scheme,
        \ 'method': g:hita#action#browse#default_method,
        \}, get(a:000, 0, {}))
  let candidates = filter(copy(a:candidates), 's:is_available(v:val)')
  let filenames = map(candidates, 'v:val.path')
  call hita#command#browse#{options.method}({
        \ 'scheme': options.scheme,
        \ 'commit': get(options, 'commit', ''),
        \ 'filenames': filenames,
        \})
endfunction

function! hita#action#browse#define_plugin_mappings() abort
  noremap <buffer><silent> <Plug>(hita-browse)
        \ :call hita#action#call('browse')<CR>
  noremap <buffer><silent> <Plug>(hita-browse-diff)
        \ :call hita#action#call('browse', {'scheme': 'diff'})<CR>
  noremap <buffer><silent> <Plug>(hita-browse-blame)
        \ :call hita#action#call('browse', {'scheme': 'blame'})<CR>
  noremap <buffer><silent> <Plug>(hita-browse-exact)
        \ :call hita#action#call('browse', {'scheme': 'exact'})<CR>
  noremap <buffer><silent> <Plug>(hita-browse-open)
        \ :call hita#action#call('browse', {'method': 'open'})<CR>
  noremap <buffer><silent> <Plug>(hita-browse-echo)
        \ :call hita#action#call('browse', {'method': 'echo'})<CR>
  noremap <buffer><silent> <Plug>(hita-browse-yank)
        \ :call hita#action#call('browse', {'method': 'yank'})<CR>
endfunction

function! hita#action#browse#define_default_mappings() abort
  map <buffer> bb <Plug>(hita-browse)
  map <buffer> bd <Plug>(hita-browse-diff)
  map <buffer> bB <Plug>(hita-browse-blame)
  map <buffer> be <Plug>(hita-browse-exact)
  map <buffer> yy <Plug>(hita-browse-yank)
endfunction

function! hita#action#browse#get_mapping_table() abort
  return s:MAPPING_TABLE
endfunction

call hita#util#define_variables('action#browse', {
      \ 'default_scheme': '_',
      \ 'default_method': 'open',
      \})
