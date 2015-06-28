let s:save_cpo = &cpo
set cpo&vim


function! s:smart_map(...) abort " {{{
  return call('gita#display#smart_map', a:000)
endfunction " }}}
function! s:ac_quitpre() abort " {{{
  let b:_gita_quitpre = 1
endfunction " }}}
function! s:ac_bufwinleave(expr) abort " {{{
  if getbufvar(a:expr, '_gita_quitpre')
    call setbufvar(a:expr, '_gita_quitpre', 0)
    let hooks = getbufvar(a:expr, '_gita_hooks')
    call hooks.call('ac_bufwinleave_pre', a:expr)
    call gita#utils#invoker#focus()
    call gita#utils#invoker#clear()
    call hooks.call('ac_bufwinleave_post', a:expr)
  endif
endfunction " }}}


let s:actions = {}
function! s:actions.help(statuses, options) abort " {{{
  call gita#utils#help#toggle(get(a:options, 'name', ''))
  if has_key(self, 'update')
    call self.update(a:statuses, a:options)
  endif
endfunction " }}}
function! s:actions.open(statuses, options) abort " {{{
  let gita = gita#core#get()
  let invoker = gita#utils#invoker#get()
  for status in a:statuses
    let path = get(status, 'path2', status.path)
    let abspath = gita.git.get_absolute_path(path)
    call invoker.focus()
    call gita#features#file#show(extend({
          \ 'file': abspath,
          \ 'commit': get(a:options, 'commit', 'WORKTREE'),
          \}, a:options))
  endfor
endfunction " }}}
function! s:actions.diff(statuses, options) abort " {{{
  let gita = gita#core#get()
  let invoker = gita#utils#invoker#get()
  for status in a:statuses
    let path = get(status, 'path2', status.path)
    let abspath = gita.git.get_absolute_path(path)
    call invoker.focus()
    call gita#features#diff#show(extend({
          \ '--': [abspath],
          \ 'commit': get(a:options, 'commit', 'INDEX'),
          \}, a:options))
  endfor
endfunction " }}}


function! gita#display#open(bufname, ...) abort  " {{{
  let gita = gita#core#get()
  if gita.fail_on_disabled()
    return -1
  endif
  let invoker = gita#utils#invoker#get()
  let options = extend(
        \ get(w:, '_gita_options', {}),
        \ get(a:000, 0, {}),
        \)

  " open a buffer in a 'gita:display' window group
  call gita#utils#buffer#open(a:bufname, 'vim_gita_display', {
        \ 'opener': 'topleft 15 split',
        \ 'range': 'tabpage',
        \})
  let w:_gita = gita
  let w:_gita_invoker = deepcopy(invoker)
  let w:_gita_options = deepcopy(options)
  let b:_gita_actions = get(b:, '_gita_actions', deepcopy(s:actions))
  let b:_gita_hooks = get(b:, '_gita_hooks', gita#utils#hooks#new())

  if get(b:, '_gita_constructed') && !get(g:, 'gita#debug')
    return 1
  endif
  let b:_gita_constructed = 1
  " construction
  setlocal buftype=nofile noswapfile nobuflisted
  setlocal winfixwidth winfixheight

  augroup vim-gita-display
    autocmd! * <buffer>
    autocmd QuitPre     <buffer> call s:ac_quitpre()
    autocmd BufWinLeave <buffer> call s:ac_bufwinleave(gita#utils#expand('<afile>'))
  augroup END

  " Define Plug key mappings
  noremap <silent><buffer> <Plug>(gita-action-quit)
        \ :<C-u>q<CR>
  noremap <silent><buffer> <Plug>(gita-action-help-s)
        \ :<C-u>call gita#display#action('help', { 'name': 'short_format' })<CR>

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
  noremap <silent><buffer> <Plug>(gita-action-compare-h)
        \ :<C-u>call gita#display#action('diff', { 'compare': 1, 'vertical': 0 })<CR>
  noremap <silent><buffer> <Plug>(gita-action-compare-v)
        \ :<C-u>call gita#display#action('diff', { 'compare': 1, 'vertical': 1 })<CR>

  if !hasmapto('<Plug>(gita-action-quit)')
    nmap <buffer> q     <Plug>(gita-action-quit)
  endif
  if !hasmapto('<Plug>(gita-action-help-s')
    nmap <buffer> ?s    <Plug>(gita-action-help-s)
  endif

  if !hasmapto('<Plug>(gita-action-open')
    nmap <buffer><expr> e <SID>smart_map('e', '<Plug>(gita-action-open)')
  endif
  if !hasmapto('<Plug>(gita-action-open-h')
    nmap <buffer><expr> <C-e> <SID>smart_map('<C-e>', '<Plug>(gita-action-open-h)')
  endif
  if !hasmapto('<Plug>(gita-action-open-v')
    nmap <buffer><expr> E <SID>smart_map('E', '<Plug>(gita-action-open-v)')
  endif

  if !hasmapto('<Plug>(gita-action-diff')
    nmap <buffer><expr> d <SID>smart_map('d', '<Plug>(gita-action-diff)')
  endif
  if !hasmapto('<Plug>(gita-action-diff-h')
    nmap <buffer><expr> <C-d> <SID>smart_map('<C-d>', '<Plug>(gita-action-diff-h)')
  endif
  if !hasmapto('<Plug>(gita-action-diff-v')
    nmap <buffer><expr> D <SID>smart_map('D', '<Plug>(gita-action-diff-v)')
  endif

  if !hasmapto('<Plug>(gita-action-compare-h')
    nmap <buffer><expr> R <SID>smart_map('R', '<Plug>(gita-action-compare-h)')
  endif
  if !hasmapto('<Plug>(gita-action-compare-v')
    nmap <buffer><expr> r <SID>smart_map('r', '<Plug>(gita-action-compare-v)')
  endif

  return 0
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
