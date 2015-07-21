let s:save_cpo = &cpo
set cpo&vim

function! s:smart_map(...) abort " {{{
  return call('gita#action#smart_map', a:000)
endfunction " }}}
function! s:get_statuses(start, end) abort " {{{
  let statuses = []
  for n in range(a:start, a:end)
    let status = get(w:_gita_statuses_map, getline(n), {})
    if !empty(status)
      call add(statuses, status)
    endif
  endfor
  return statuses
endfunction " }}}
function! s:ac_QuitPre() abort " {{{
  let b:_gita_monitor_QuitPre = 1
endfunction " }}}
function! s:ac_WinLeave() abort " {{{
  if get(b:, '_gita_monitor_QuitPre')
    call gita#utils#hooks#call('ac_WinLeave')
    call gita#utils#anchor#focus()
  endif
  silent! unlet b:_gita_monitor_QuitPre
endfunction " }}}
function! s:ac_WinLeaveVim703() abort " {{{
  if histget('cmd') =~# '\v^%(q|quit|wq)$'
    call gita#utils#hooks#call('ac_WinLeave')
    call gita#utils#anchor#focus()
  endif
endfunction " }}}

function! gita#monitor#open(bufname, ...) abort  " {{{
  let gita = gita#get()
  if gita.fail_on_disabled()
    return { 'status': -1, 'constructed': 0 }
  endif
  let options = extend(
        \ get(w:, '_gita_options', {}),
        \ get(a:000, 0, {}),
        \)
  let config = extend({
        \ 'opener': '',
        \ 'range': '',
        \}, get(a:000, 1, {}))

  " open a buffer in a 'gita:monitor' window group
  let result = gita#utils#buffer#open(
        \ a:bufname, 'vim_gita_monitor', {
        \ 'opener': empty(config.opener)
        \   ? g:gita#monitor#opener
        \   : config.opener,
        \ 'range': empty(config.range)
        \   ? g:gita#monitor#range
        \   : config.range,
        \})
  let w:_gita = gita
  let w:_gita_options = deepcopy(options)
  let w:_gita_statuses_map = {}
  call gita#action#set_candidates(function('s:get_statuses'))

  if get(b:, '_gita_constructed') && !g:gita#debug
    return {
          \ 'status': 0,
          \ 'constructed': 1,
          \ 'loaded': result.loaded,
          \ 'bufnum': result.bufnum,
          \}
  endif
  let b:_gita_constructed = 1
  setlocal buftype=nofile bufhidden=hide noswapfile nobuflisted
  setlocal winfixwidth winfixheight

  augroup vim-gita-monitor
    autocmd! * <buffer>
    if exists('#QuitPre')
      autocmd QuitPre  <buffer> call s:ac_QuitPre()
      autocmd WinLeave <buffer> call s:ac_WinLeave()
    else
      " Note:
      "
      " QuitPre was introduced since Vim 7.3.544
      " https://github.com/vim-jp/vim/commit/4e7db56d
      "
      " :wq       : QuitPre > BufWriteCmd > WinLeave > BufWinLeave
      " :q        : QuitPre > WinLeave > BufWinLeave
      " :e        : BufWinLeave
      " :wincmd w : WinLeave
      "
      autocmd WinLeave <buffer> call s:ac_WinLeaveVim703()
    endif
  augroup END

  return {
        \ 'status': 0,
        \ 'constructed': 0,
        \ 'loaded': result.loaded,
        \ 'bufnum': result.bufnum,
        \}
endfunction " }}}
function! gita#monitor#define_mappings() abort " {{{
  noremap <silent><buffer> <Plug>(gita-action-quit)
        \ :<C-u>q<CR>
  noremap <silent><buffer> <Plug>(gita-action-help-s)
        \ :<C-u>call gita#action#exec('help', { 'name': 'short_format' })<CR>

  noremap <silent><buffer> <Plug>(gita-action-edit)
        \ :<C-u>call gita#action#exec('edit')<CR>
  noremap <silent><buffer> <Plug>(gita-action-edit-h)
        \ :<C-u>call gita#action#exec('edit', { 'opener': 'split' })<CR>
  noremap <silent><buffer> <Plug>(gita-action-edit-v)
        \ :<C-u>call gita#action#exec('edit', { 'opener': 'vsplit' })<CR>

  noremap <silent><buffer> <Plug>(gita-action-open)
        \ :<C-u>call gita#action#exec('open')<CR>
  noremap <silent><buffer> <Plug>(gita-action-open-h)
        \ :<C-u>call gita#action#exec('open', { 'opener': 'split' })<CR>
  noremap <silent><buffer> <Plug>(gita-action-open-v)
        \ :<C-u>call gita#action#exec('open', { 'opener': 'vsplit' })<CR>

  noremap <silent><buffer> <Plug>(gita-action-diff)
        \ :<C-u>call gita#action#exec('diff')<CR>
  noremap <silent><buffer> <Plug>(gita-action-diff-h)
        \ :<C-u>call gita#action#exec('diff', { 'opener': 'split' })<CR>
  noremap <silent><buffer> <Plug>(gita-action-diff-v)
        \ :<C-u>call gita#action#exec('diff', { 'opener': 'vsplit' })<CR>
  noremap <silent><buffer> <Plug>(gita-action-DIFF-h)
        \ :<C-u>call gita#action#exec('diff', { 'window': 'double', 'vertical': 0 })<CR>
  noremap <silent><buffer> <Plug>(gita-action-DIFF-v)
        \ :<C-u>call gita#action#exec('diff', { 'window': 'double', 'vertical': 1 })<CR>
endfunction " }}}
function! gita#monitor#define_default_mappings() abort " {{{
  nmap <buffer> q     <Plug>(gita-action-quit)
  nmap <buffer> ?s    <Plug>(gita-action-help-s)

  nmap <buffer><expr> ee <SID>smart_map('ee', '<Plug>(gita-action-edit)')
  nmap <buffer><expr> eh <SID>smart_map('eh', '<Plug>(gita-action-edit-h)')
  nmap <buffer><expr> ev <SID>smart_map('ev', '<Plug>(gita-action-edit-v)')
  nmap <buffer><expr> eE <SID>smart_map('eE', '<Plug>(gita-action-edit-v)')
  nmap <buffer><expr> EE <SID>smart_map('EE', '<Plug>(gita-action-edit-v)')

  nmap <buffer><expr> oo <SID>smart_map('oo', '<Plug>(gita-action-open)')
  nmap <buffer><expr> oh <SID>smart_map('oh', '<Plug>(gita-action-open-h)')
  nmap <buffer><expr> ov <SID>smart_map('ov', '<Plug>(gita-action-open-v)')
  nmap <buffer><expr> oO <SID>smart_map('oO', '<Plug>(gita-action-open-v)')
  nmap <buffer><expr> OO <SID>smart_map('OO', '<Plug>(gita-action-open-v)')

  nmap <buffer><expr> dd <SID>smart_map('dd', '<Plug>(gita-action-diff)')
  nmap <buffer><expr> dh <SID>smart_map('dh', '<Plug>(gita-action-diff-h)')
  nmap <buffer><expr> dv <SID>smart_map('dv', '<Plug>(gita-action-diff-v)')

  nmap <buffer><expr> dD <SID>smart_map('dD', '<Plug>(gita-action-DIFF-v)')
  nmap <buffer><expr> dH <SID>smart_map('dH', '<Plug>(gita-action-DIFF-h)')
  nmap <buffer><expr> dV <SID>smart_map('dV', '<Plug>(gita-action-DIFF-v)')
  nmap <buffer><expr> DD <SID>smart_map('DD', '<Plug>(gita-action-DIFF-v)')
  nmap <buffer><expr> DH <SID>smart_map('DH', '<Plug>(gita-action-DIFF-h)')
  nmap <buffer><expr> DV <SID>smart_map('DV', '<Plug>(gita-action-DIFF-v)')
endfunction " }}}


let &cpo = s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
