function! s:action(candidate, options) abort
  call gita#content#status#open({})
endfunction

function! gita#action#status#define(disable_mapping) abort
  call gita#action#define('status:open', function('s:action'), {
        \ 'description': 'Open gita-status window',
        \ 'mapping_mode': 'n',
        \ 'options': {},
        \})
  if a:disable_mapping
    return
  endif
  let content_type = gita#meta#get('content_type')
  if content_type ==# 'commit'
    nmap <buffer><nowait> <C-^> <Plug>(gita-status-open)
    nmap <buffer><nowait> <C-6> <Plug>(gita-status-open)
  endif
endfunction
