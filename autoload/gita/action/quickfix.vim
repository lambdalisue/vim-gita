function! s:build_qflist(candidates) abort
  let git = gita#core#get()
  let qflist = []
  for candidate in a:candidates
    call add(qflist, {
          \ 'filename': gita#normalize#abspath(git, candidate.path),
          \ 'lnum': candidate.selection[0],
          \ 'text': candidate.content,
          \})
  endfor
  return qflist
endfunction

function! s:action_quickfix(candidates, options) abort
  call setqflist(s:build_qflist(a:candidates))
endfunction

function! s:action_locationlist(candidates, options) abort
  call setloclist(0, s:build_qflist(a:candidates))
endfunction

function! gita#action#quickfix#define(disable_mapping) abort
  call gita#action#define('quickfix:quickfix', function('s:action_quickfix'), {
        \ 'alias': 'quickfix',
        \ 'description': 'Add candidates to quickfix',
        \ 'requirements': ['path', 'selection', 'content'],
        \ 'options': {},
        \})
  call gita#action#define('quickfix:locationlist', function('s:action_locationlist'), {
        \ 'alias': 'locationlist',
        \ 'description': 'Add candidates to location-list',
        \ 'requirements': ['path', 'selection', 'content'],
        \ 'options': {},
        \})
  if a:disable_mapping
    return
  endif
  nmap <buffer><nowait><expr> qq gita#action#smart_map('qq', '<Plug>(gita-quickfix-quickfix)')
  vmap <buffer><nowait><expr> qq gita#action#smart_map('qq', '<Plug>(gita-quickfix-quickfix)')
  nmap <buffer><nowait><expr> ql gita#action#smart_map('ql', '<Plug>(gita-quickfix-locationlist)')
  vmap <buffer><nowait><expr> ql gita#action#smart_map('ql', '<Plug>(gita-quickfix-locationlist)')
endfunction
