function! s:action(candidates, options) abort
  let options = extend({
        \ 'anchor': 1,
        \ 'opener': '',
        \ 'method': g:gita#action#patch#default_method,
        \}, a:options)
  call gita#option#assign_selection(options, g:gita#action#patch#default_opener)
  let options.selection = get(options, 'selection', [])
  for candidate in a:candidates
    if has_key(candidate, 'path')
      call gita#command#patch#open({
            \ 'method': options.method,
            \ 'anchor': options.anchor,
            \ 'opener': options.opener,
            \ 'filename': candidate.path,
            \ 'selection': get(candidate, 'selection', options.selection)
            \})
    endif
  endfor
endfunction

function! gita#action#patch#define(disable_mapping) abort
  call gita#action#define('patch', function('s:action'), {
        \ 'description': 'Patch file contents to the index',
        \ 'mapping_mode': 'n',
        \ 'options': {},
        \})
  call gita#action#define('patch:one', function('s:action'), {
        \ 'description': 'Patch file contents to the index (one way)',
        \ 'mapping_mode': 'n',
        \ 'options': { 'method': 'one' },
        \})
  call gita#action#define('patch:two', function('s:action'), {
        \ 'description': 'Patch file contents to the index (two way)',
        \ 'mapping_mode': 'n',
        \ 'options': { 'method': 'two' },
        \})
  call gita#action#define('patch:three', function('s:action'), {
        \ 'description': 'Patch file contents to the index (three way)',
        \ 'mapping_mode': 'n',
        \ 'options': { 'method': 'three' },
        \})
  if a:disable_mapping
    return
  endif
  nmap <buffer><nowait><expr> pp gita#action#smart_map('pp', '<Plug>(gita-patch)')
  nmap <buffer><nowait><expr> p1 gita#action#smart_map('p1', '<Plug>(gita-patch-one)')
  nmap <buffer><nowait><expr> p2 gita#action#smart_map('p2', '<Plug>(gita-patch-two)')
  nmap <buffer><nowait><expr> p3 gita#action#smart_map('p3', '<Plug>(gita-patch-three)')
endfunction

call gita#util#define_variables('action#patch', {
      \ 'default_method': '',
      \ 'default_opener': '',
      \})
