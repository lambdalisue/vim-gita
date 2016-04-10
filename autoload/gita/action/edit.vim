let s:V = gita#vital()
let s:BufferAnchor = s:V.import('Vim.Buffer.Anchor')

function! s:action(candidate, options) abort
  let options = extend({
        \ 'opener': '',
        \ 'selection': [],
        \}, a:options)
  call gita#util#option#assign_opener(options)
  call gita#util#option#assign_selection(options)
  let selection = get(a:candidate, 'selection', options.selection)
  let opener = empty(options.opener) ? 'edit' : options.opener
  if s:BufferAnchor.is_available(opener)
    call s:BufferAnchor.focus()
  endif
  call gita#content#show#open({
        \ 'worktree': 1,
        \ 'filename': a:candidate.path,
        \ 'opener': opener,
        \ 'selection': selection,
        \})
endfunction

function! gita#action#edit#define(disable_mapping) abort
  call gita#action#define('edit', function('s:action'), {
        \ 'description': 'Open a content',
        \ 'mapping_mode': 'n',
        \ 'requirements': ['path'],
        \ 'options': {},
        \})
  call gita#action#define('edit:edit', function('s:action'), {
        \ 'description': 'Open a content (edit)',
        \ 'mapping_mode': 'n',
        \ 'requirements': ['path'],
        \ 'options': { 'opener': 'edit' },
        \})
  call gita#action#define('edit:above', function('s:action'), {
        \ 'alias': 'above',
        \ 'description': 'Open a content (above)',
        \ 'mapping_mode': 'n',
        \ 'requirements': ['path'],
        \ 'options': { 'opener': 'leftabove new' },
        \})
  call gita#action#define('edit:below', function('s:action'), {
        \ 'alias': 'below',
        \ 'description': 'Open a content (below)',
        \ 'mapping_mode': 'n',
        \ 'requirements': ['path'],
        \ 'options': { 'opener': 'rightbelow new' },
        \})
  call gita#action#define('edit:left', function('s:action'), {
        \ 'alias': 'left',
        \ 'description': 'Open a content (left)',
        \ 'mapping_mode': 'n',
        \ 'requirements': ['path'],
        \ 'options': { 'opener': 'leftabove vnew' },
        \})
  call gita#action#define('edit:right', function('s:action'), {
        \ 'alias': 'right',
        \ 'description': 'Open a content (right)',
        \ 'mapping_mode': 'n',
        \ 'requirements': ['path'],
        \ 'options': { 'opener': 'rightbelow vnew' },
        \})
  call gita#action#define('edit:tab', function('s:action'), {
        \ 'alias': 'tab',
        \ 'description': 'Open a content (tab)',
        \ 'mapping_mode': 'n',
        \ 'requirements': ['path'],
        \ 'options': { 'opener': 'tabnew' },
        \})
  call gita#action#define('edit:preview', function('s:action'), {
        \ 'alias': 'preview',
        \ 'description': 'Open a content (preview)',
        \ 'mapping_mode': 'n',
        \ 'requirements': ['path'],
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
