function! s:action(candidate, options) abort
  if !a:candidate.is_conflicted
    call gita#throw(printf(
          \ 'A file %s is not conflicted. Chaperone is for solving conflict.',
          \ a:candidate.path,
          \))
  endif
  let options = extend({
        \ 'anchor': 1,
        \ 'opener': '',
        \ 'method': g:gita#action#chaperone#default_method,
        \}, a:options)
  call gita#option#assign_selection(options)
  call gita#option#assign_opener(options)
  let options.selection = get(options, 'selection', [])
  call gita#command#ui#chaperone#open({
        \ 'method': options.method,
        \ 'anchor': options.anchor,
        \ 'opener': options.opener,
        \ 'filename': a:candidate.path,
        \ 'selection': get(a:candidate, 'selection', options.selection)
        \})
endfunction

function! gita#action#chaperone#define(disable_mapping) abort
  call gita#action#define('chaperone', function('s:action'), {
        \ 'description': 'Help to solve conflict',
        \ 'mapping_mode': 'n',
        \ 'requirements': ['path', 'is_conflicted'],
        \ 'options': {},
        \})
  "call gita#action#define('chaperone:one', function('s:action'), {
  "      \ 'description': 'Help to solve conflict (one way)',
  "      \ 'mapping_mode': 'n',
  "      \ 'requirements': ['path', 'is_conflicted'],
  "      \ 'options': { 'method': 'one' },
  "      \})
  call gita#action#define('chaperone:two', function('s:action'), {
        \ 'description': 'Help to solve conflict (two way)',
        \ 'mapping_mode': 'n',
        \ 'requirements': ['path', 'is_conflicted'],
        \ 'options': { 'method': 'two' },
        \})
  call gita#action#define('chaperone:three', function('s:action'), {
        \ 'description': 'Help to solve conflict (three way)',
        \ 'mapping_mode': 'n',
        \ 'requirements': ['path', 'is_conflicted'],
        \ 'options': { 'method': 'three' },
        \})
  if a:disable_mapping
    return
  endif
  nmap <buffer><nowait><expr> !! gita#action#smart_map('!!', '<Plug>(gita-chaperone)')
  "nmap <buffer><nowait><expr> !1 gita#action#smart_map('!1', '<Plug>(gita-chaperone-one)')
  nmap <buffer><nowait><expr> !2 gita#action#smart_map('!2', '<Plug>(gita-chaperone-two)')
  nmap <buffer><nowait><expr> !3 gita#action#smart_map('!3', '<Plug>(gita-chaperone-three)')
endfunction

call gita#util#define_variables('action#chaperone', {
      \ 'default_method': '',
      \})

