function! s:action(candidates, options) abort
  let options = extend({
        \ 'scheme': g:gita#action#browse#default_scheme,
        \ 'method': g:gita#action#browse#default_method,
        \}, a:options)
  call gita#option#assign_commit(options)
  call gita#option#assign_selection(options)
  let options.commit = get(options, 'commit', '')
  let options.selection = get(options, 'selection', [])
  for candidate in a:candidates
    if has_key(candidate, 'path')
      call gita#command#browse#{options.method}({
            \ 'scheme': options.scheme,
            \ 'filename': candidate.path,
            \ 'commit': get(candidate, 'commit', options.commit),
            \ 'selection': get(candidate, 'selection', options.selection),
            \})
    endif
  endfor
endfunction

function! gita#action#browse#define(disable_mappings) abort
  call gita#action#define('browse', function('s:action'), {
        \ 'description': 'Browse a content',
        \ 'mapping_mode': 'n',
        \ 'options': {},
        \})
  call gita#action#define('browse:exact', function('s:action'), {
        \ 'description': 'Browse a content URL of "exact" scheme',
        \ 'mapping_mode': 'n',
        \ 'options': { 'scheme': 'exact' },
        \})
  call gita#action#define('browse:diff', function('s:action'), {
        \ 'description': 'Browse a content URL of "diff" scheme',
        \ 'mapping_mode': 'n',
        \ 'options': { 'scheme': 'diff' },
        \})
  call gita#action#define('browse:blame', function('s:action'), {
        \ 'description': 'Browse a content URL of "blame" scheme',
        \ 'mapping_mode': 'n',
        \ 'options': { 'scheme': 'blame' },
        \})
  call gita#action#define('browse:repository', function('s:action'), {
        \ 'description': 'Browse a repository URL of the content',
        \ 'mapping_mode': 'n',
        \ 'options': { 'repository': 1 },
        \})

  call gita#action#define('browse:open:exact', function('s:action'), {
        \ 'description': 'Open a content of "exact" scheme',
        \ 'mapping_mode': 'n',
        \ 'options': { 'scheme': 'exact', 'method': 'open' },
        \})
  call gita#action#define('browse:open:diff', function('s:action'), {
        \ 'description': 'Open a content of "diff" scheme',
        \ 'mapping_mode': 'n',
        \ 'options': { 'scheme': 'diff', 'method': 'open' },
        \})
  call gita#action#define('browse:open:blame', function('s:action'), {
        \ 'description': 'Open a content URL of "blame" scheme',
        \ 'mapping_mode': 'n',
        \ 'options': { 'scheme': 'blame', 'method': 'open' },
        \})
  call gita#action#define('browse:open:repository', function('s:action'), {
        \ 'description': 'Open a repository URL of the content',
        \ 'mapping_mode': 'n',
        \ 'options': { 'repository': 1, 'method': 'open' },
        \})

  call gita#action#define('browse:yank:exact', function('s:action'), {
        \ 'description': 'Yank a content of "exact" scheme',
        \ 'mapping_mode': 'n',
        \ 'options': { 'scheme': 'exact', 'method': 'yank' },
        \})
  call gita#action#define('browse:yank:diff', function('s:action'), {
        \ 'description': 'Yank a content of "diff" scheme',
        \ 'mapping_mode': 'n',
        \ 'options': { 'scheme': 'diff', 'method': 'yank'  },
        \})
  call gita#action#define('browse:yank:blame', function('s:action'), {
        \ 'description': 'Yank a content URL of "blame" scheme',
        \ 'mapping_mode': 'n',
        \ 'options': { 'scheme': 'blame', 'method': 'yank'  },
        \})
  call gita#action#define('browse:yank:repository', function('s:action'), {
        \ 'description': 'Yank a repository URL of the content',
        \ 'mapping_mode': 'n',
        \ 'options': { 'repository': 1, 'method': 'yank'  },
        \})
  if a:disable_mappings
    return
  endif
  nmap <buffer><nowait><expr> bb gita#action#smart_map('bb', '<Plug>(gita-browse)')
  nmap <buffer><nowait><expr> yy gita#action#smart_map('yy', '<Plug>(gita-browse-yank)')
endfunction

call gita#util#define_variables('action#browse', {
      \ 'default_scheme': '_',
      \ 'default_method': 'open',
      \})
