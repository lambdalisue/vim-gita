let s:save_cpo = &cpo
set cpo&vim


let s:D = gita#utils#import('Data.Dict')


function! s:ac_quit() abort " {{{
  " Note:
  " A vim help said the current buffer '%' may be different from the buffer
  " being unloaded <afile> in BufWinLeave autocmd but if I consider the case,
  " the code will " be more complicated thus now I simply trust that the
  " current buffer is the buffer being unloaded.
  if get(b:, '_winleave', 0)
    let hooks = get(w:, '_gita_hooks', gita#utils#hooks#new())
    call hooks.call('pre_ac_quit')
    call gita#utils#invoker#focus()
    call gita#utils#invoker#clear()
    call hooks.call('post_ac_quit')
  endif
endfunction " }}}
function! s:action(name, ...) abort range " {{{
  let options = get(a:000, 0, {})
  let config = get(a:000, 1, {})
  if get(config, 'extend_options')
    let options = gita#window#extend_options(options)
  endif

  let firstline = get(config, 'firstline', a:firstline)
  let lastline = get(config, 'lastline', a:lastline)
  let statuses = gita#window#get_statuses_within(firstline, lastline)
  let args = [statuses, options]
  " Note: no error handling should be performed to figure out the error
  call call(w:_gita_actions[a:name], args, w:_gita_actions)
endfunction " }}}
function! s:smart_map(lhs, rhs) abort " {{{
  return empty(gita#window#get_status_at(a:firstline))
        \ ? a:lhs
        \ : a:rhs
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
  let opener = get(a:options, 'opener', 'edit')
  for status in a:statuses
    let path = get(status, 'path2', status.path)
    let abspath = gita.git.get_absolute_path(path)
    call invoker.focus()
    call gita#utils#buffer#open(abspath, '', {
          \ 'opener': opener,
          \})
  endfor
endfunction " }}}


function! gita#window#smart_map(lhs, rhs) abort " {{{
  return s:smart_map(a:lhs, a:rhs)
endfunction " }}}
function! gita#window#extend_options(options) abort " {{{
  return extend(
        \ deepcopy(get(w:, '_gita_options', {})),
        \ a:options,
        \)
endfunction " }}}
function! gita#window#get_status_at(lineno) abort " {{{
  let statuses = gita#window#get_statuses_within(a:lineno, a:lineno)
  return get(statuses, 0, '')
endfunction " }}}
function! gita#window#get_statuses_within(start, end) abort " {{{
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
function! gita#window#open(name, ...) abort " {{{
  let gita = gita#core#get()
  if !gita.enabled
    redraw
    call gita#utils#warn(
          \ 'Gita is not available in the current buffer.',
          \)
    return
  endif

  let options = gita#window#extend_options(get(a:000, 0, {}))
  let config = get(a:000, 1, {})
  let invoker = gita#utils#invoker#get()

  let bufname_sep = has('unix') ? ':' : '_'
  let bufname = get(config, 'bufname',
        \ join(['gita', a:name], bufname_sep),
        \)
  " TODO: Add user options of 'opener'
  call gita#utils#buffer#open(bufname, 'window', {
        \ 'opener': 'topleft 15 split',
        \ 'range': 'tabpage',
        \})

  " use fresh options
  if get(options, 'new', 0)
    let options = get(a:000, 0, {})
  endif
  " Note:
  "   w:_gita is prior to b:_gita in gita#core#get()
  "   while the 'range' of support_window is 'tabpage'
  "   no buffer variable should be used to store status
  "   expect 'b:_gita_construct' which indicate that the
  "   buffer is already constructed or not.
  let w:_gita = gita
  let w:_gita_options = s:D.omit(options, [
        \ 'new'
        \])
  let w:_gita_actions = get(w:, '_gita_actions', deepcopy(s:actions))
  let w:_gita_hooks = get(w:, '_gita_hooks', gita#utils#hooks#new())
  call invoker.update_winnum()
  call gita#utils#invoker#set(invoker)
  " check if construction is required
  if get(b:, '_gita_constructed') && !get(g:, 'gita#debug', 0)
    let filetype = get(config, 'filetype',
          \ printf('gita-%s', a:name)
          \)
    silent execute printf('setlocal filetype=%s', filetype)
    return
  endif
  let b:_gita_constructed = 1
  " construction
  setlocal buftype=nofile bufhidden=wipe noswapfile nobuflisted
  setlocal winfixwidth winfixheight

  augroup vim-gita-window
    autocmd! * <buffer>
    " Note:
    "
    " :wq       : QuitPre > BufWriteCmd > WinLeave > BufWinLeave
    " :q        : QuitPre > WinLeave > BufWinLeave
    " :e        : BufWinLeave
    " :wincmd w : WinLeave
    "
    " s:ac_quit need to be called after BufWriteCmd and only when closing a
    " buffre window (not when :e, :wincmd w).
    " That's why the following autocmd combination is required.
    autocmd WinEnter    <buffer> let b:_winleave = 0
    autocmd WinLeave    <buffer> let b:_winleave = 1
    autocmd BufWinEnter <buffer> let b:_winleave = 0
    autocmd BufWinLeave <buffer> call s:ac_quit()
  augroup END

  noremap <silent><buffer> <Plug>(gita-action-close)  :<C-u>quit<CR>
  noremap <silent><buffer> <Plug>(gita-action-help-m) :<C-u>call <SID>action('help', { 'name': 'window_mapping' })<CR>
  noremap <silent><buffer> <Plug>(gita-action-help-s) :<C-u>call <SID>action('help', { 'name': 'short_format' })<CR>
  noremap <silent><buffer> <Plug>(gita-action-open)   :<C-u>call <SID>action('open')<CR>
  noremap <silent><buffer> <Plug>(gita-action-open-h) :<C-u>call <SID>action('open', { 'opener': 'botright split' })<CR>
  noremap <silent><buffer> <Plug>(gita-action-open-v) :<C-u>call <SID>action('open', { 'opener': 'botright vsplit' })<CR>

  if get(g:, printf('gita#features#%s#enable_default_keymap', a:name), 1)
    nmap <buffer> q     <Plug>(gita-action-close)
    nmap <buffer> ?m    <Plug>(gita-action-help-m)
    nmap <buffer> ?s    <Plug>(gita-action-help-s)
    nmap <buffer><expr> e <SID>smart_map('e', '<Plug>(gita-action-open)')
    nmap <buffer><expr> E <SID>smart_map('E', '<Plug>(gita-action-open-v)')
  endif
  
  " Note:
  " filetype assignment should become the last step while filetype autocmd
  " might re-define mappings or whatever.
  let filetype = get(config, 'filetype',
        \ printf('gita-%s', a:name)
        \)
  silent execute printf('setlocal filetype=%s', filetype)
endfunction " }}}
function! gita#window#action(name, ...) abort range " {{{
  let options = get(a:000, 0, {})
  let config = extend(get(a:000, 1, {}), {
        \ 'firstline': a:firstline,
        \ 'lastline': a:lastline,
        \})
  call s:action(a:name, options, config)
endfunction " }}}
function! gita#window#extend_actions(actions) abort " {{{
  let w:_gita_actions = extend(
        \ get(w:, '_gita_actions', deepcopy(s:actions)),
        \ a:actions,
        \)
endfunction " }}}


let &cpo = s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
