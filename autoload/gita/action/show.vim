function! s:action(candidate, options) abort
  let options = extend({
        \ 'anchor': 1,
        \ 'opener': '',
        \ 'selection': [],
        \}, a:options)
  call gita#option#assign_commit(options)
  call gita#option#assign_opener(options)
  call gita#option#assign_selection(options)
  let options.selection = get(a:candidate, 'selection', options.selection)
  let args = [
        \ empty(options.anchor) ? '' : '--anchor',
        \ empty(options.opener) ? '' : '--opener=' . shellescape(options.opener),
        \ empty(options.selection) ? '' : '--selection=' . printf('%d-%d',
        \   options.selection[0], get(options.selection, 1, options.selection[0])
        \ ),
        \ get(a:candidate, 'commit', get(options, 'commit', '')),
        \]
  let args += ['--', fnameescape(a:candidate.path)]
  execute 'Gita show ' . join(filter(args, '!empty(v:val)'))
endfunction

function! gita#action#show#define(disable_mapping) abort
  call gita#action#define('show', function('s:action'), {
        \ 'description': 'Show a content',
        \ 'mapping_mode': 'n',
        \ 'requirements': ['path'],
        \ 'options': {},
        \})
  call gita#action#define('show:edit', function('s:action'), {
        \ 'description': 'Show a content (edit)',
        \ 'mapping_mode': 'n',
        \ 'requirements': ['path'],
        \ 'options': { 'opener': 'edit' },
        \})
  call gita#action#define('show:above', function('s:action'), {
        \ 'description': 'Show a content (above)',
        \ 'mapping_mode': 'n',
        \ 'requirements': ['path'],
        \ 'options': { 'opener': 'leftabove new' },
        \})
  call gita#action#define('show:below', function('s:action'), {
        \ 'description': 'Show a content (below)',
        \ 'mapping_mode': 'n',
        \ 'requirements': ['path'],
        \ 'options': { 'opener': 'rightbelow new' },
        \})
  call gita#action#define('show:left', function('s:action'), {
        \ 'description': 'Show a content (left)',
        \ 'mapping_mode': 'n',
        \ 'requirements': ['path'],
        \ 'options': { 'opener': 'leftabove vnew' },
        \})
  call gita#action#define('show:right', function('s:action'), {
        \ 'description': 'Show a content (right)',
        \ 'mapping_mode': 'n',
        \ 'requirements': ['path'],
        \ 'options': { 'opener': 'rightbelow vnew' },
        \})
  call gita#action#define('show:tab', function('s:action'), {
        \ 'description': 'Show a content (tab)',
        \ 'mapping_mode': 'n',
        \ 'requirements': ['path'],
        \ 'options': { 'opener': 'tabnew' },
        \})
  call gita#action#define('show:preview', function('s:action'), {
        \ 'description': 'Show a content (preview)',
        \ 'mapping_mode': 'n',
        \ 'requirements': ['path'],
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
