let s:V = gita#vital()
let s:File = s:V.import('System.File')

function! s:action(candidate, options) abort
  let options = extend({
        \ 'repository': 0,
        \ 'scheme': '_',
        \ 'yank': 0,
        \}, a:options)
  call gita#util#option#assign_commit(options)
  call gita#util#option#assign_selection(options)

  let commit = get(a:candidate, 'commit', get(options, 'commit', ''))
  let selection = get(a:candidate, 'selection', options.selection)
  let git = gita#core#get_or_fail()
  let url = gita#command#browse#call(git, {
        \ 'commit': commit,
        \ 'filename': a:candidate.path,
        \ 'repository': options.repository,
        \ 'scheme': options.scheme,
        \ 'selection': selection,
        \})
  if options.yank
    call gita#util#clip(url)
  else
    call gita#util#browse(url)
  endif
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
        \ 'options': { 'yank': 1 },
        \})
  call gita#action#define('browse:exact:yank', function('s:action'), {
        \ 'description': 'Yank a content of "exact" scheme',
        \ 'mapping_mode': 'n',
        \ 'requirements': ['path'],
        \ 'options': { 'scheme': 'exact', 'yank': 1 },
        \})
  call gita#action#define('browse:diff:yank', function('s:action'), {
        \ 'description': 'Yank a content of "diff" scheme',
        \ 'mapping_mode': 'n',
        \ 'requirements': ['path'],
        \ 'options': { 'scheme': 'diff', 'yank': 1  },
        \})
  call gita#action#define('browse:blame:yank', function('s:action'), {
        \ 'description': 'Yank a content URL of "blame" scheme',
        \ 'mapping_mode': 'n',
        \ 'requirements': ['path'],
        \ 'options': { 'scheme': 'blame', 'yank': 1  },
        \})
  call gita#action#define('browse:repository:yank', function('s:action'), {
        \ 'description': 'Yank a repository URL of the content',
        \ 'mapping_mode': 'n',
        \ 'requirements': ['path'],
        \ 'options': { 'repository': 1, 'yank': 1  },
        \})
  if a:disable_mappings
    return
  endif
  nmap <buffer><nowait><expr> bb gita#action#smart_map('bb', '<Plug>(gita-browse)')
  nmap <buffer><nowait><expr> yy gita#action#smart_map('yy', '<Plug>(gita-browse-yank)')
endfunction
