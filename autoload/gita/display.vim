let s:save_cpo = &cpo
set cpo&vim

function! s:smart_map(...) abort " {{{
  return call('gita#display#smart_map', a:000)
endfunction " }}}
function! s:ac_QuitPre() abort " {{{
  let b:_gita_QuitPre = 1
endfunction " }}}
function! s:ac_WinLeave() abort " {{{
  if get(b:, '_gita_QuitPre')
    unlet! b:_gita_QuitPre
    let hooks = b:_gita_hooks
    call hooks.call('ac_WinLeave_pre')
    call gita#anchor#focus()
    call hooks.call('ac_WinLeave_post')
  endif
endfunction " }}}


let s:actions = {}
function! s:actions.help(statuses, options) abort " {{{
  call gita#utils#help#toggle(get(a:options, 'name', ''))
  if has_key(self, 'update')
    call self.update(a:statuses, a:options)
  endif
endfunction " }}}
function! s:actions.edit(statuses, options) abort " {{{
  let gita = gita#get()
  for status in a:statuses
    let path = get(status, 'path2', status.path)
    let abspath = gita.git.get_absolute_path(path)
    call gita#anchor#focus()
    call gita#utils#buffer#open(abspath, '', a:options)
  endfor
endfunction " }}}
function! s:actions.open(statuses, options) abort " {{{
  let gita = gita#get()
  " gita#features#file#show cannot treat master... thus remove the trailing
  " characters after ..[.]
  let commit = get(a:options, 'commit', 'HEAD')
  let commit = substitute(commit, '\v\.\.\.?.*$', '', '')
  let commit = substitute(commit, '\v^\.\.\.?', '', '')
  for status in a:statuses
    call gita#anchor#focus()
    call gita#features#file#show(extend(a:options, {
          \ 'file': status.path,
          \ 'commit': commit,
          \}))
  endfor
endfunction " }}}
function! s:actions.diff(statuses, options) abort " {{{
  let gita = gita#get()
  for status in a:statuses
    let path = get(status, 'path2', status.path)
    let abspath = gita.git.get_absolute_path(path)
    call gita#anchor#focus()
    call gita#features#diff#show(extend(a:options, {
          \ '--': [abspath],
          \ 'commit': get(a:options, 'commit', 'INDEX'),
          \}))
  endfor
endfunction " }}}


function! gita#display#open(bufname, ...) abort  " {{{
  let gita = gita#get()
  if gita.fail_on_disabled()
    return { 'status': -1 }
  endif
  let options = extend(
        \ get(w:, '_gita_options', {}),
        \ get(a:000, 0, {}),
        \)
  let config = get(a:000, 1, {})

  " open a buffer in a 'gita:display' window group
  let open_result = gita#utils#buffer#open(a:bufname, 'vim_gita_display', {
        \ 'opener': 'topleft 15 split',
        \ 'range': 'tabpage',
        \})
  let w:_gita = gita
  let w:_gita_options = deepcopy(options)
  let b:_gita_actions = get(b:, '_gita_actions', deepcopy(s:actions))
  let b:_gita_hooks = get(b:, '_gita_hooks', gita#utils#hooks#new())

  if get(b:, '_gita_constructed') && !g:gita#debug
    return {
          \ 'status': 1,
          \ 'loaded': open_result.loaded,
          \ 'bufnum': open_result.bufnum,
          \}
  endif
  let b:_gita_constructed = 1
  " construction
  setlocal buftype=nofile noswapfile nobuflisted
  setlocal winfixwidth winfixheight

  augroup vim-gita-display
    autocmd! * <buffer>
    autocmd QuitPre  <buffer> call s:ac_QuitPre()
    autocmd WinLeave <buffer> call s:ac_WinLeave()
  augroup END

  " Define Plug key mappings
  noremap <silent><buffer> <Plug>(gita-action-quit)
        \ :<C-u>q<CR>
  noremap <silent><buffer> <Plug>(gita-action-help-s)
        \ :<C-u>call gita#display#action('help', { 'name': 'short_format' })<CR>

  noremap <silent><buffer> <Plug>(gita-action-edit)
        \ :<C-u>call gita#display#action('edit')<CR>
  noremap <silent><buffer> <Plug>(gita-action-edit-h)
        \ :<C-u>call gita#display#action('edit', { 'opener': 'split' })<CR>
  noremap <silent><buffer> <Plug>(gita-action-edit-v)
        \ :<C-u>call gita#display#action('edit', { 'opener': 'vsplit' })<CR>

  noremap <silent><buffer> <Plug>(gita-action-open)
        \ :<C-u>call gita#display#action('open')<CR>
  noremap <silent><buffer> <Plug>(gita-action-open-h)
        \ :<C-u>call gita#display#action('open', { 'opener': 'split' })<CR>
  noremap <silent><buffer> <Plug>(gita-action-open-v)
        \ :<C-u>call gita#display#action('open', { 'opener': 'vsplit' })<CR>

  noremap <silent><buffer> <Plug>(gita-action-diff)
        \ :<C-u>call gita#display#action('diff')<CR>
  noremap <silent><buffer> <Plug>(gita-action-diff-h)
        \ :<C-u>call gita#display#action('diff', { 'opener': 'split' })<CR>
  noremap <silent><buffer> <Plug>(gita-action-diff-v)
        \ :<C-u>call gita#display#action('diff', { 'opener': 'vsplit' })<CR>
  noremap <silent><buffer> <Plug>(gita-action-DIFF-h)
        \ :<C-u>call gita#display#action('diff', { 'compare': 1, 'vertical': 0 })<CR>
  noremap <silent><buffer> <Plug>(gita-action-DIFF-v)
        \ :<C-u>call gita#display#action('diff', { 'compare': 1, 'vertical': 1 })<CR>

  if get(config, 'enable_default_mappings')
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
  endif

  return {
        \ 'status': 0,
        \ 'loaded': open_result.loaded,
        \ 'bufnum': open_result.bufnum,
        \}
endfunction " }}}
function! gita#display#smart_map(lhs, rhs) abort " {{{
  return empty(gita#display#get_status_at(a:firstline))
        \ ? a:lhs
        \ : a:rhs
endfunction " }}}
function! gita#display#get_status_at(lineno) abort " {{{
  let statuses = gita#display#get_statuses_within(
        \ a:lineno, a:lineno
        \)
  return get(statuses, 0, '')
endfunction " }}}
function! gita#display#get_statuses_within(start, end) abort " {{{
  let statuses_map = get(w:, '_gita_statuses_map', {})
  let statuses = []
  for n in range(a:start, a:end)
    let status = get(statuses_map, getline(n), {})
    if !empty(status)
      call add(statuses, status)
    endif
  endfor
  return statuses
endfunction " }}}

function! gita#display#action(name, ...) abort range " {{{
  let options = extend(
        \ get(w:, '_gita_options', {}),
        \ get(a:000, 0, {}),
        \)
  let statuses = gita#display#get_statuses_within(
        \ a:firstline, a:lastline
        \)
  let args = [statuses, options]
  call call(b:_gita_actions[a:name], args, b:_gita_actions)
endfunction " }}}
function! gita#display#extend_actions(actions) abort " {{{
  let w:_gita_actions = extend(
        \ get(b:, '_gita_actions', deepcopy(s:actions)),
        \ a:actions,
        \)
endfunction " }}}


let &cpo = s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
