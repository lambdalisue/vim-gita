let s:V = gita#vital()
let s:BufferAnchor = s:V.import('Vim.Buffer.Anchor')

function! s:action(candidate, options) abort
  let options = extend({
        \ 'opener': '',
        \ 'selection': [],
        \ 'method': '',
        \}, a:options)
  call gita#util#option#assign_opener(options)
  call gita#util#option#assign_selection(options)
  let selection = get(a:candidate, 'selection', options.selection)
  let opener = empty(options.opener) ? 'tabedit' : options.opener
  if s:BufferAnchor.is_available(opener)
    call s:BufferAnchor.focus()
  endif
  call gita#content#patch#open({
        \ 'filename': a:candidate.path,
        \ 'opener': opener,
        \ 'selection': selection,
        \ 'method': options.method,
        \})
endfunction

function! gita#action#patch#define(disable_mapping) abort
  call gita#action#define('patch', function('s:action'), {
        \ 'description': 'Patch file contents to the index',
        \ 'mapping_mode': 'n',
        \ 'requirements': ['path'],
        \ 'options': {},
        \})
  call gita#action#define('patch:one', function('s:action'), {
        \ 'description': 'Patch file contents to the index (one way)',
        \ 'mapping_mode': 'n',
        \ 'requirements': ['path'],
        \ 'options': { 'method': 'one' },
        \})
  call gita#action#define('patch:two', function('s:action'), {
        \ 'description': 'Patch file contents to the index (two way)',
        \ 'mapping_mode': 'n',
        \ 'requirements': ['path'],
        \ 'options': { 'method': 'two' },
        \})
  call gita#action#define('patch:three', function('s:action'), {
        \ 'description': 'Patch file contents to the index (three way)',
        \ 'mapping_mode': 'n',
        \ 'requirements': ['path'],
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
