function! s:action(candidate, options) abort
  let options = extend({
        \ 'amend': -1,
        \}, a:options)
  let filenames = gita#meta#get('filenames', [])
  if options.amend == -1
    call gita#command#ui#commit#open({
          \ 'filenames': filenames,
          \})
  else
    call gita#command#ui#commit#open({
          \ 'amend': options.amend,
          \ 'filenames': filenames,
          \})
  endif
endfunction

function! gita#action#commit#define(disable_mapping) abort
  call gita#action#define('commit', function('s:action'), {
        \ 'description': 'Open gita-commit window',
        \ 'mapping_mode': 'n',
        \ 'options': {},
        \})
  call gita#action#define('commit:new', function('s:action'), {
        \ 'description': 'Open a NEW gita-commit window',
        \ 'mapping_mode': 'n',
        \ 'options': { 'amend': 0 },
        \})
  call gita#action#define('commit:amend', function('s:action'), {
        \ 'description': 'Open an AMEND gita-commit window',
        \ 'mapping_mode': 'n',
        \ 'options': { 'amend': 1 },
        \})
  if a:disable_mapping
    return
  endif
endfunction
