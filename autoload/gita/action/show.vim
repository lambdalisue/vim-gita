function! s:action(candidates, options) abort
  let options = extend({
        \ 'anchor': 1,
        \ 'opener': ''
        \}, a:options)
  call gita#option#assign_commit(options)
  call gita#option#assign_selection(options)
  call gita#option#assign_opener(options, g:gita#action#show#default_opener)
  let options.commit = get(options, 'commit', '')
  let options.selection = get(options, 'selection', [])
  for candidate in a:candidates
    if has_key(candidate, 'path')
      call gita#command#show#open({
            \ 'anchor': options.anchor,
            \ 'opener': options.opener,
            \ 'filename': candidate.path,
            \ 'commit': get(candidate, 'commit', options.commit),
            \ 'selection': get(candidate, 'selection', options.selection),
            \})
    endif
  endfor
endfunction

function! gita#action#show#define(disable_mapping) abort
  call gita#action#define('show', function('s:action'), {
        \ 'description': 'Show a content',
        \ 'mapping_mode': 'n',
        \ 'options': {},
        \})
  call gita#action#define('show:edit', function('s:action'), {
        \ 'description': 'Show a content (edit)',
        \ 'mapping_mode': 'n',
        \ 'options': { 'opener': 'edit' },
        \})
  call gita#action#define('show:above', function('s:action'), {
        \ 'description': 'Show a content (above)',
        \ 'mapping_mode': 'n',
        \ 'options': { 'opener': 'leftabove new' },
        \})
  call gita#action#define('show:below', function('s:action'), {
        \ 'description': 'Show a content (below)',
        \ 'mapping_mode': 'n',
        \ 'options': { 'opener': 'rightbelow new' },
        \})
  call gita#action#define('show:left', function('s:action'), {
        \ 'description': 'Show a content (left)',
        \ 'mapping_mode': 'n',
        \ 'options': { 'opener': 'leftabove vnew' },
        \})
  call gita#action#define('show:right', function('s:action'), {
        \ 'description': 'Show a content (right)',
        \ 'mapping_mode': 'n',
        \ 'options': { 'opener': 'rightbelow vnew' },
        \})
  call gita#action#define('show:tab', function('s:action'), {
        \ 'description': 'Show a content (tab)',
        \ 'mapping_mode': 'n',
        \ 'options': { 'opener': 'tabnew' },
        \})
  call gita#action#define('show:preview', function('s:action'), {
        \ 'description': 'Show a content (preview)',
        \ 'mapping_mode': 'n',
        \ 'options': { 'opener': 'pedit' },
        \})
  if a:disable_mapping
    return
  endif
  nmap <buffer><nowait><expr> ss gita#action#smart_map('ss', '<Plug>(gita-show)')
  nmap <buffer><nowait><expr> SS gita#action#smart_map('SS', '<Plug>(gita-show-right)')
  nmap <buffer><nowait><expr> st gita#action#smart_map('st', '<Plug>(gita-show-tab)')
  nmap <buffer><nowait><expr> sp gita#action#smart_map('sp', '<Plug>(gita-show-preview)')
endfunction

call gita#util#define_variables('action#show', {
      \ 'default_opener': '',
      \})
