function! s:action(candidates, options) abort
  let options = extend({
        \ 'anchor': 1,
        \ 'opener': '',
        \}, a:options)
  call gita#option#assign_selection(options)
  call gita#option#assign_opener(options, g:gita#action#edit#default_opener)
  let options.selection = get(options, 'selection', [])
  for candidate in a:candidates
    if has_key(candidate, 'path')
      call gita#command#show#open({
            \ 'worktree': 1,
            \ 'anchor': options.anchor,
            \ 'opener': options.opener,
            \ 'filename': get(candidate, 'path2', candidate.path),
            \ 'selection': get(candidate, 'selection', options.selection),
            \})
    endif
  endfor
endfunction

function! gita#action#edit#define(disable_mapping) abort
  call gita#action#define('edit', function('s:action'), {
        \ 'description': 'Open a content',
        \ 'mapping_mode': 'n',
        \ 'options': {},
        \})
  call gita#action#define('edit:edit', function('s:action'), {
        \ 'description': 'Open a content (edit)',
        \ 'mapping_mode': 'n',
        \ 'options': { 'opener': 'edit' },
        \})
  call gita#action#define('edit:above', function('s:action'), {
        \ 'description': 'Open a content (above)',
        \ 'mapping_mode': 'n',
        \ 'options': { 'opener': 'leftabove new' },
        \})
  call gita#action#define('edit:below', function('s:action'), {
        \ 'description': 'Open a content (below)',
        \ 'mapping_mode': 'n',
        \ 'options': { 'opener': 'rightbelow new' },
        \})
  call gita#action#define('edit:left', function('s:action'), {
        \ 'description': 'Open a content (left)',
        \ 'mapping_mode': 'n',
        \ 'options': { 'opener': 'leftabove vnew' },
        \})
  call gita#action#define('edit:right', function('s:action'), {
        \ 'description': 'Open a content (right)',
        \ 'mapping_mode': 'n',
        \ 'options': { 'opener': 'rightbelow vnew' },
        \})
  call gita#action#define('edit:tab', function('s:action'), {
        \ 'description': 'Open a content (tab)',
        \ 'mapping_mode': 'n',
        \ 'options': { 'opener': 'tabnew' },
        \})
  call gita#action#define('edit:preview', function('s:action'), {
        \ 'description': 'Open a content (preview)',
        \ 'mapping_mode': 'n',
        \ 'options': { 'opener': 'pedit' },
        \})
  if a:disable_mapping
    return
  endif
  nmap <buffer><nowait><expr> ee gita#action#smart_map('ee', '<Plug>(gita-edit)')
  nmap <buffer><nowait><expr> EE gita#action#smart_map('EE', '<Plug>(gita-edit-right)')
  nmap <buffer><nowait><expr> et gita#action#smart_map('et', '<Plug>(gita-edit-tab)')
  nmap <buffer><nowait><expr> ep gita#action#smart_map('ep', '<Plug>(gita-edit-preview)')
endfunction

call gita#util#define_variables('action#edit', {
      \ 'default_opener': '',
      \})
