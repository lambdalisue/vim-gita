function! s:action(candidate, options) abort
  let options = extend({
        \ 'anchor': 1,
        \ 'opener': '',
        \}, a:options)
  call gita#option#assign_commit(options)
  call gita#option#assign_selection(options)
  call gita#option#assign_opener(options)
  let options.commit = get(options, 'commit', '')
  let options.selection = get(options, 'selection', [])
  call gita#command#ui#blame#open({
        \ 'anchor': options.anchor,
        \ 'opener': options.opener,
        \ 'filename': a:candidate.path,
        \ 'commit': get(a:candidate, 'commit', options.commit),
        \ 'selection': get(a:candidate, 'selection', options.selection),
        \})
endfunction

function! gita#action#blame#define(disable_mappings) abort
  call gita#action#define('blame', function('s:action'), {
        \ 'description': 'Blame a content',
        \ 'mapping_mode': 'n',
        \ 'requirements': ['path'],
        \ 'options': {},
        \})
  if a:disable_mappings
    return
  endif
  nmap <buffer><nowait><expr> BB gita#action#smart_map('BB', '<Plug>(gita-blame)')
endfunction

call gita#util#define_variables('action#blame', {
      \ 'default_opener': '',
      \})
