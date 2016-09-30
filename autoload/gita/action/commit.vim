function! s:action_open(candidate, options) abort
  let options = extend({
        \ 'amend': 0,
        \}, a:options)
  call gita#content#commit#open({
        \ 'amend': options.amend,
        \})
endfunction

function! gita#action#commit#define(disable_mapping) abort
  call gita#action#define('commit:open', function('s:action_open'), {
        \ 'description': 'Open gita-commit window',
        \ 'mapping_mode': 'n',
        \ 'options': {},
        \})
  call gita#action#define('commit:open:amend', function('s:action_open'), {
        \ 'description': 'Open an AMEND gita-commit window',
        \ 'mapping_mode': 'n',
        \ 'options': { 'amend': 1 },
        \})
  if a:disable_mapping
    return
  endif
  let content_type = gita#meta#get('content_type')
  if content_type ==# 'commit'
    nmap <buffer><nowait> <C-c><C-n> <Plug>(gita-commit-open)
    nmap <buffer><nowait> <C-c><C-a> <Plug>(gita-commit-open-amend)
  elseif content_type ==# 'status'
    nmap <buffer><nowait> <C-^> <Plug>(gita-commit-open)
    nmap <buffer><nowait> <C-6> <Plug>(gita-commit-open)
  endif
endfunction
