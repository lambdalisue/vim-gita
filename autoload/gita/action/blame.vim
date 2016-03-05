function! s:action(candidates, options) abort
  let options = extend({
        \ 'anchor': 1,
        \ 'opener': '',
        \}, a:options)
  call gita#option#assign_commit(options)
  call gita#option#assign_selection(options)
  call gita#option#assign_opener(options, g:gita#action#blame#default_opener)
  let options.commit = get(options, 'commit', '')
  let options.selection = get(options, 'selection', [])
  for candidate in a:candidates
    if has_key(candidate, 'path')
      call gita#command#blame#open({
            \ 'anchor': options.anchor,
            \ 'opener': options.opener,
            \ 'filename': candidate.path,
            \ 'commit': get(candidate, 'commit', options.commit),
            \ 'selection': get(candidate, 'selection', options.selection),
            \})
    endif
  endfor
endfunction

function! gita#action#blame#define(disable_mappings) abort
  call gita#action#define('blame', function('s:action'), {
        \ 'description': 'Blame a content',
        \ 'mapping_mode': 'n',
        \ 'options': {},
        \})
  if a:disable_mappings
    return
  endif
  nmap <buffer><nowait><expr> BB gita#action#smart_map('BB', '<Plug>(gita-blame)')
endfunction

call gita#util#define_variables('action#blame', {
      \ 'default_opener': 'tabnew',
      \})
