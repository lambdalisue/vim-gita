let s:V = gita#vital()
let s:Anchor = s:V.import('Vim.Buffer.Anchor')
let s:MAPPING_TABLE = {
      \ '<Plug>(gita-add)': 'Add file contents to the index',
      \ '<Plug>(gita-ADD)': 'Add file contents to the index (force)',
      \ '<Plug>(gita-add-p)': 'Add file contents to the index with PATCH mode',
      \}

function! gita#action#add#action(candidates, ...) abort
  let options = extend({
        \ 'force': 0,
        \ 'patch': 0,
        \}, get(a:000, 0, {}))
  let filenames = []
  for candidate in a:candidates
    if has_key(candidate, 'path')
      call add(filenames, get(candidate, 'path2', candidate.path))
    endif
  endfor
  if !empty(filenames)
    if options.patch
      call s:Anchor.focus()
      call gita#command#add#patch({
            \ 'quiet': 1,
            \ 'filenames': filenames,
            \ 'patch': options.patch,
            \})
    else
      call gita#command#add#call({
            \ 'quiet': 1,
            \ 'filenames': filenames,
            \ 'force': options.force,
            \ 'patch': options.patch,
            \ 'ignore-errors': 1,
            \})
    endif
  endif
endfunction

function! gita#action#add#define_plugin_mappings() abort
  noremap <buffer><silent> <Plug>(gita-add)
        \ :call gita#action#call('add')<CR>
  noremap <buffer><silent> <Plug>(gita-ADD)
        \ :call gita#action#call('add', { 'force': 1 })<CR>
  nnoremap <buffer><silent> <Plug>(gita-add-p)
        \ :<C-u>call gita#action#call('add', { 'patch': 1 })<CR>
endfunction

function! gita#action#add#define_default_mappings() abort
  map <buffer><nowait><expr> -a gita#action#smart_map('-a', '<Plug>(gita-add)')
  map <buffer><nowait><expr> -A gita#action#smart_map('-A', '<Plug>(gita-ADD)')
  nmap <buffer><nowait><expr> -p gita#action#smart_map('-p', '<Plug>(gita-add-p)')
endfunction

function! gita#action#add#get_mapping_table() abort
  return s:MAPPING_TABLE
endfunction

function! gita#action#add#define_action(...) abort
  call gita#action#register('add', function('s:action'), {
        \ 'description': 'Add file contents to the index',
        \ 'kwargs': {},
        \})
  call gita#action#register('add-force', function('s:action'), {
        \ 'description': 'Add file contents to the index (force)',
        \ 'kwargs': {
        \   'force': 1,
        \ },
        \})
  call gita#action#register('add-patch', function('s:action'), {
        \ 'description': 'Add file contents to the index with PATCH mode',
        \ 'mapping_mode': 'n',
        \ 'kwargs': {
        \   'patch': 1,
        \ },
        \})
endfunction

function! gita#action#add#define_mapping(enable_default) abort
  if a:enable_default
    nmap <buffer><nowait><expr> -a gita#action#smart_map('-a', '<Plug>(gita-add)')
    nmap <buffer><nowait><expr> -A gita#action#smart_map('-A', '<Plug>(gita-add-force)')
    vmap <buffer><nowait><expr> -a gita#action#smart_map('-a', '<Plug>(gita-add)')
    vmap <buffer><nowait><expr> -A gita#action#smart_map('-A', '<Plug>(gita-add-force)')
    nmap <buffer><nowait><expr> -p gita#action#smart_map('-p', '<Plug>(gita-add-patch)')
  endif
endfunction
