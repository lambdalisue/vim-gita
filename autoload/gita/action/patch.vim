function! s:action(candidate, options) abort
  let options = extend({
        \ 'anchor': 1,
        \ 'opener': '',
        \ 'selection': [],
        \ 'method': g:gita#action#patch#default_method,
        \}, a:options)
  call gita#option#assign_opener(options)
  call gita#option#assign_selection(options)
  let args = [
        \ empty(options.anchor) ? '' : '--anchor',
        \ empty(options.opener) ? '' : '--opener=' . shellescape(options.opener),
        \ empty(options.selection) ? '' : '--selection=' . printf('%d-%d',
        \   options.selection[0], get(options.selection, 1, options.selection[0])
        \ ),
        \]
  let args += empty(options.method) ? [] : ['--' . options.method]
  let args += ['--', fnameescape(a:candidate.path)]
  execute 'Gita patch ' . join(filter(args, '!empty(v:val)'))
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

call gita#util#define_variables('action#patch', {
      \ 'default_method': '',
      \})
