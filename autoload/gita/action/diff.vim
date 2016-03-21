function! s:action(candidate, options) abort
  let options = extend({
        \ 'anchor': 1,
        \ 'opener': '',
        \ 'split': g:gita#action#diff#default_split,
        \}, a:options)
  call gita#option#assign_commit(options)
  call gita#option#assign_selection(options)
  call gita#option#assign_opener(options)
  let options.commit = get(options, 'commit', '')
  let options.selection = get(options, 'selection', [])
  call gita#ui#diff#open({
        \ 'split': options.split,
        \ 'anchor': options.anchor,
        \ 'opener': options.opener,
        \ 'filename': a:candidate.path,
        \ 'commit': get(a:candidate, 'commit', options.commit),
        \ 'selection': get(a:candidate, 'selection', options.selection),
        \ 'cached': !get(a:candidate, 'is_unstaged', 1),
        \})
endfunction

function! gita#action#diff#define(disable_mapping) abort
  call gita#action#define('diff', function('s:action'), {
        \ 'description': 'Show a diff content',
        \ 'mapping_mode': 'n',
        \ 'requirements': ['path'],
        \ 'options': {},
        \})
  call gita#action#define('diff:edit', function('s:action'), {
        \ 'description': 'Show a diff content (edit)',
        \ 'mapping_mode': 'n',
        \ 'requirements': ['path'],
        \ 'options': { 'split': 0, 'opener': 'edit' },
        \})
  call gita#action#define('diff:above', function('s:action'), {
        \ 'description': 'Show a diff content (above)',
        \ 'mapping_mode': 'n',
        \ 'requirements': ['path'],
        \ 'options': { 'split': 0, 'opener': 'leftabove new' },
        \})
  call gita#action#define('diff:below', function('s:action'), {
        \ 'description': 'Show a diff content (below)',
        \ 'mapping_mode': 'n',
        \ 'requirements': ['path'],
        \ 'options': { 'split': 0, 'opener': 'rightbelow new' },
        \})
  call gita#action#define('diff:left', function('s:action'), {
        \ 'description': 'Show a diff content (left)',
        \ 'mapping_mode': 'n',
        \ 'requirements': ['path'],
        \ 'options': { 'split': 0, 'opener': 'leftabove vnew' },
        \})
  call gita#action#define('diff:right', function('s:action'), {
        \ 'description': 'Show a diff content (right)',
        \ 'mapping_mode': 'n',
        \ 'requirements': ['path'],
        \ 'options': { 'split': 0, 'opener': 'rightbelow vnew' },
        \})
  call gita#action#define('diff:tab', function('s:action'), {
        \ 'description': 'Show a diff content (tab)',
        \ 'mapping_mode': 'n',
        \ 'requirements': ['path'],
        \ 'options': { 'split': 0, 'opener': 'tabnew' },
        \})
  call gita#action#define('diff:preview', function('s:action'), {
        \ 'description': 'Show a diff content (preview)',
        \ 'mapping_mode': 'n',
        \ 'requirements': ['path'],
        \ 'options': { 'split': 0, 'opener': 'pedit' },
        \})
  call gita#action#define('diff:split', function('s:action'), {
        \ 'description': 'Show a diff content (split)',
        \ 'mapping_mode': 'n',
        \ 'requirements': ['path'],
        \ 'options': { 'split': 1 },
        \})
  call gita#action#define('diff:split:tab', function('s:action'), {
        \ 'description': 'Show a diff content (split tab)',
        \ 'mapping_mode': 'n',
        \ 'requirements': ['path'],
        \ 'options': { 'split': 1, 'opener': 'tabnew' },
        \})
  if a:disable_mapping
    return
  endif
  nmap <buffer><nowait><expr> dd gita#action#smart_map('dd', '<Plug>(gita-diff)')
  nmap <buffer><nowait><expr> DD gita#action#smart_map('DD', '<Plug>(gita-diff-right)')
  nmap <buffer><nowait><expr> dt gita#action#smart_map('dt', '<Plug>(gita-diff-tab)')
  nmap <buffer><nowait><expr> dp gita#action#smart_map('dp', '<Plug>(gita-diff-preview)')
  nmap <buffer><nowait><expr> ds gita#action#smart_map('ds', '<Plug>(gita-diff-split)')
  nmap <buffer><nowait><expr> DS gita#action#smart_map('DS', '<Plug>(gita-diff-split-tab)')
endfunction

call gita#util#define_variables('action#diff', {
      \ 'default_split': 0,
      \})
