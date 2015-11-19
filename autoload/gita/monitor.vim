let s:save_cpoptions = &cpoptions
set cpoptions&vim

function! s:smart_map(...) abort " {{{
  return call('gita#action#smart_map', a:000)
endfunction " }}}
function! s:get_candidates(start, end, ...) abort " {{{
  let options = get(a:000, 0, {})
  let commit = get(options, 'commit', gita#meta#get('commit', ''))
  let candidates = []
  for n in range(a:start, a:end)
    let status = get(w:_gita_statuses_map, getline(n), {})
    if !empty(status)
      let candidate = gita#action#new_candidate(status.path, empty(commit)
            \ ? status.is_unstaged ? 'INDEX' : 'HEAD'
            \ : commit
            \)
      call gita#utils#status#extend_candidate(candidate, status)
      call add(candidates, candidate)
    endif
  endfor
  return candidates
endfunction " }}}
function! s:ac_QuitPre() abort " {{{
  let w:_gita_monitor_QuitPre = 1
endfunction " }}}
function! s:ac_WinLeave() abort " {{{
  if get(w:, '_gita_monitor_QuitPre')
    call gita#utils#hooks#call('ac_WinLeave')
    call gita#utils#anchor#focus()
  endif
  silent! unlet w:_gita_monitor_QuitPre
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
        \ a:bufname, {
        \ 'group': 'vim_gita_monitor',
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
  call gita#action#register_get_candidates(function('s:get_candidates'))

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

  " vim-gita monitor window does not support <C-o>/<C-u> because it use
  " window variable which will cause some complex issue on opening the buffer
  " without throughing gita#features#xxxx#open
  " Issue #57
  map <silent><buffer> <C-o> :<C-u>call gita#utils#prompt#warn('CTRL-O is not supported on monitor window')<CR>
  map <silent><buffer> <C-i> :<C-u>call gita#utils#prompt#warn('CTRL-I is not supported on monitor window')<CR>

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
        \ :<C-u>call gita#action#call('help', { 'name': 'short_format' })<CR>

  noremap <silent><buffer> <Plug>(gita-action-edit)
        \ :<C-u>call gita#action#call('edit')<CR>
  noremap <silent><buffer> <Plug>(gita-action-edit-h)
        \ :<C-u>call gita#action#call('edit', { 'opener': 'split' })<CR>
  noremap <silent><buffer> <Plug>(gita-action-edit-v)
        \ :<C-u>call gita#action#call('edit', { 'opener': 'vsplit' })<CR>

  noremap <silent><buffer> <Plug>(gita-action-open)
        \ :<C-u>call gita#action#call('open')<CR>
  noremap <silent><buffer> <Plug>(gita-action-open-h)
        \ :<C-u>call gita#action#call('open', { 'opener': 'split' })<CR>
  noremap <silent><buffer> <Plug>(gita-action-open-v)
        \ :<C-u>call gita#action#call('open', { 'opener': 'vsplit' })<CR>

  noremap <silent><buffer> <Plug>(gita-action-diff)
        \ :<C-u>call gita#action#call('diff', { 'split': 0 })<CR>
  noremap <silent><buffer> <Plug>(gita-action-diff-h)
        \ :<C-u>call gita#action#call('diff', { 'split': 0, 'opener': 'split' })<CR>
  noremap <silent><buffer> <Plug>(gita-action-diff-v)
        \ :<C-u>call gita#action#call('diff', { 'split': 0, 'opener': 'vsplit' })<CR>
  noremap <silent><buffer> <Plug>(gita-action-DIFF-h)
        \ :<C-u>call gita#action#call('diff', { 'vertical': 0 })<CR>
  noremap <silent><buffer> <Plug>(gita-action-DIFF-v)
        \ :<C-u>call gita#action#call('diff', { 'vertical': 1 })<CR>

  noremap <silent><buffer> <Plug>(gita-action-browse-open)
        \ :<C-u>call gita#action#call('browse')<CR>
  noremap <silent><buffer> <Plug>(gita-action-browse-echo)
        \ :<C-u>call gita#action#call('browse', { 'echo': 1 })<CR>
  noremap <silent><buffer> <Plug>(gita-action-browse-yank)
        \ :<C-u>call gita#action#call('browse', { 'yank': 1 })<CR>
  noremap <silent><buffer> <Plug>(gita-action-BROWSE-OPEN)
        \ :<C-u>call gita#action#call('browse', { 'scheme': 'exact' })<CR>
  noremap <silent><buffer> <Plug>(gita-action-BROWSE-ECHO)
        \ :<C-u>call gita#action#call('browse', { 'echo': 1, 'scheme': 'exact' })<CR>
  noremap <silent><buffer> <Plug>(gita-action-BROWSE-YANK)
        \ :<C-u>call gita#action#call('browse', { 'yank': 1, 'scheme': 'exact' })<CR>

  noremap <silent><buffer> <Plug>(gita-action-blame)
        \ :<C-u>call gita#action#call('blame')<CR>
  noremap <silent><buffer> <Plug>(gita-action-blame-browse)
        \ :<C-u>call gita#action#call('browse', { 'scheme': 'blame' })<CR>

  noremap <silent><buffer> <Plug>(gita-action-add)
        \ :call gita#action#call('add')<CR>
  noremap <silent><buffer> <Plug>(gita-action-ADD)
        \ :call gita#action#call('add', { 'force': 1 })<CR>
  noremap <silent><buffer> <Plug>(gita-action-rm)
        \ :call gita#action#call('rm')<CR>
  noremap <silent><buffer> <Plug>(gita-action-RM)
        \ :call gita#action#call('rm', { 'force': 1 })<CR>
  noremap <silent><buffer> <Plug>(gita-action-reset)
        \ :call gita#action#call('reset')<CR>
  noremap <silent><buffer> <Plug>(gita-action-checkout)
        \ :call gita#action#call('checkout')<CR>
  noremap <silent><buffer> <Plug>(gita-action-CHECKOUT)
        \ :call gita#action#call('checkout', { 'force': 1 })<CR>
  noremap <silent><buffer> <Plug>(gita-action-checkout-ours)
        \ :call gita#action#call('checkout', { 'ours': 1 })<CR>
  noremap <silent><buffer> <Plug>(gita-action-checkout-theirs)
        \ :call gita#action#call('checkout', { 'theirs': 1 })<CR>
  noremap <silent><buffer> <Plug>(gita-action-stage)
        \ :call gita#action#call('stage')<CR>
  noremap <silent><buffer> <Plug>(gita-action-unstage)
        \ :call gita#action#call('unstage')<CR>
  noremap <silent><buffer> <Plug>(gita-action-toggle)
        \ :call gita#action#call('toggle')<CR>
  noremap <silent><buffer> <Plug>(gita-action-discard)
        \ :call gita#action#call('discard')<CR>

  noremap <silent><buffer> <Plug>(gita-action-conflict2-h)
        \ :call gita#action#call('conflict', { 'way': 2 })<CR>
  noremap <silent><buffer> <Plug>(gita-action-conflict2-v)
        \ :call gita#action#call('conflict', { 'way': 2, 'vertical': 1 })<CR>
  noremap <silent><buffer> <Plug>(gita-action-conflict3-h)
        \ :call gita#action#call('conflict', { 'way': 3 })<CR>
  noremap <silent><buffer> <Plug>(gita-action-conflict3-v)
        \ :call gita#action#call('conflict', { 'way': 3, 'vertical': 1 })<CR>
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

  nmap <buffer><expr> uo <SID>smart_map('uo', '<Plug>(gita-action-browse-open)')
  nmap <buffer><expr> ue <SID>smart_map('ue', '<Plug>(gita-action-browse-echo)')
  nmap <buffer><expr> uy <SID>smart_map('uy', '<Plug>(gita-action-browse-yank)')
  nmap <buffer><expr> uO <SID>smart_map('uO', '<Plug>(gita-action-BROWSE-OPEN)')
  nmap <buffer><expr> uE <SID>smart_map('uE', '<Plug>(gita-action-BROWSE-ECHO)')
  nmap <buffer><expr> uY <SID>smart_map('uY', '<Plug>(gita-action-BROWSE-YANK)')
  nmap <buffer><expr> UO <SID>smart_map('UO', '<Plug>(gita-action-BROWSE-OPEN)')
  nmap <buffer><expr> UE <SID>smart_map('UE', '<Plug>(gita-action-BROWSE-ECHO)')
  nmap <buffer><expr> UY <SID>smart_map('UY', '<Plug>(gita-action-BROWSE-YANK)')

  nmap <buffer><expr> bb <SID>smart_map('bb', '<Plug>(gita-action-blame)')
  nmap <buffer><expr> bB <SID>smart_map('bB', '<Plug>(gita-action-blame-browse)')
  nmap <buffer><expr> BB <SID>smart_map('BB', '<Plug>(gita-action-blame-browse)')
endfunction " }}}

augroup vim-gita-update-monitor
  autocmd! *
  autocmd BufWritePost * call gita#action#call('update')
augroup END

let &cpoptions = s:save_cpoptions
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
