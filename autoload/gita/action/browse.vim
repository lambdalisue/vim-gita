function! s:action(candidate, options) abort
  let options = extend({
        \ 'repository': 0,
        \ 'scheme': g:gita#action#browse#default_scheme,
        \ 'method': g:gita#action#browse#default_method,
        \}, a:options)
  call gita#option#assign_commit(options)
  call gita#option#assign_selection(options)

  let args = [
        \ empty(options.repository) ? '' : '--repository',
        \ empty(options.scheme) ? '' : '--scheme=' . options.scheme,
        \ empty(options.selection) ? '' : '--selection=' . printf('%d-%d',
        \   options.selection[0], get(options.selection, 1, options.selection[0])
        \ ),
        \]
  let args += !empty(options.method)
        \ ? options.method ==# 'open'
        \   ? ['--open']
        \   : options.method ==# 'yank'
        \     ? ['--yank']
        \     : options.method ==# 'echo'
        \       ? ['--echo']
        \       : []
        \ : []
  let args += [get(a:candidate, 'commit', get(options, 'commit', ''))]
  execute 'Gita browse ' . join(filter(args, '!empty(v:val)'))
endfunction

function! gita#action#browse#define(disable_mappings) abort
  call gita#action#define('browse', function('s:action'), {
        \ 'description': 'Browse a content URL',
        \ 'mapping_mode': 'n',
        \ 'requirements': ['path'],
        \ 'options': {},
        \})
  call gita#action#define('browse:exact', function('s:action'), {
        \ 'description': 'Browse a content URL of "exact" scheme',
        \ 'mapping_mode': 'n',
        \ 'requirements': ['path'],
        \ 'options': { 'scheme': 'exact' },
        \})
  call gita#action#define('browse:diff', function('s:action'), {
        \ 'description': 'Browse a content URL of "diff" scheme',
        \ 'mapping_mode': 'n',
        \ 'requirements': ['path'],
        \ 'options': { 'scheme': 'diff' },
        \})
  call gita#action#define('browse:blame', function('s:action'), {
        \ 'description': 'Browse a content URL of "blame" scheme',
        \ 'mapping_mode': 'n',
        \ 'requirements': ['path'],
        \ 'options': { 'scheme': 'blame' },
        \})
  call gita#action#define('browse:repository', function('s:action'), {
        \ 'description': 'Browse a repository URL of the content',
        \ 'mapping_mode': 'n',
        \ 'requirements': ['path'],
        \ 'options': { 'repository': 1 },
        \})
  call gita#action#define('browse:yank', function('s:action'), {
        \ 'description': 'Yank a content URL',
        \ 'mapping_mode': 'n',
        \ 'requirements': ['path'],
        \ 'options': { 'method': 'yank' },
        \})
  call gita#action#define('browse:exact:yank', function('s:action'), {
        \ 'description': 'Yank a content of "exact" scheme',
        \ 'mapping_mode': 'n',
        \ 'requirements': ['path'],
        \ 'options': { 'scheme': 'exact', 'method': 'yank' },
        \})
  call gita#action#define('browse:diff:yank', function('s:action'), {
        \ 'description': 'Yank a content of "diff" scheme',
        \ 'mapping_mode': 'n',
        \ 'requirements': ['path'],
        \ 'options': { 'scheme': 'diff', 'method': 'yank'  },
        \})
  call gita#action#define('browse:blame:yank', function('s:action'), {
        \ 'description': 'Yank a content URL of "blame" scheme',
        \ 'mapping_mode': 'n',
        \ 'requirements': ['path'],
        \ 'options': { 'scheme': 'blame', 'method': 'yank'  },
        \})
  call gita#action#define('browse:repository:yank', function('s:action'), {
        \ 'description': 'Yank a repository URL of the content',
        \ 'mapping_mode': 'n',
        \ 'requirements': ['path'],
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
