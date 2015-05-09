let s:save_cpo = &cpo
set cpo&vim

let s:const = {}
let s:const.bufname = has('unix') ? 'gita:status' : 'gita_status'
let s:const.filetype = 'gita-status'

let s:L = gita#utils#import('Data.List')

function! s:get_gita(...) abort " {{{
  let gita = call('gita#core#get', a:000)
  let gita.features = get(gita, 'features', {})
  let gita.features.status = get(gita.features, 'status', {})
  return gita
endfunction " }}}
function! s:get_selected_status() abort " {{{
  let gita = s:get_gita()
  let statuses_map = get(gita.features.status, 'statuses_map', {})
  let selected_line = getline('.')
  return get(statuses_map, selected_line, {})
endfunction " }}}
function! s:get_selected_statuses() abort " {{{
  let gita = s:get_gita()
  let statuses_map = get(gita.features.status, 'statuses_map', {})
  let selected_lines = getline(getpos("'<")[1], getpos("'>")[1])
  let selected_statuses = []
  for selected_line in selected_lines
    let status = get(statuses_map, selected_line, {})
    if !empty(status)
      call add(selected_statuses, status)
    endif
  endfor
  return selected_statuses
endfunction " }}}

function! s:smart_map(lhs, rhs) abort " {{{
  return empty(s:get_selected_status()) ? a:lhs : a:rhs
endfunction " }}}

function! s:open(...) abort " {{{
  let config = extend(
        \ get(b:, '_config', {}),
        \ get(a:000, 0, {}),
        \)
  let gita = s:get_gita()

  if !gita.enabled
    redraw | call gita#utils#info(printf(
          \ 'Git is not available in the current buffer "%s".',
          \ bufname('%'),
          \))
    return -1
  endif

  let ret = gita#utils#buffer#open(s:const.bufname, 'support_window', {
        \ 'opener': 'topleft 15 split',
        \ 'range': 'tabpage',
        \})
  silent execute printf('setlocal filetype=%s', s:const.filetype)

  let b:_gita = gita
  let b:_config = config

  " check if construction is required
  if exists('b:_constructed') && !get(g:, 'gita#debug', 0)
    return ret.bufnr
  endif

  " construction
  setlocal buftype=nofile bufhidden=hide noswapfile nobuflisted
  setlocal winfixwidth winfixheight
  setlocal cursorline
  setlocal nomodifiable

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
  autocmd BufWinLeave <buffer> if get(b:, '_winleave', 0) | call s:ac_quit() | endif

  call s:defmap()
  call s:update(config)
  let b:_constructed = 1
  return ret.bufnr
endfunction " }}}

function! s:update(...) abort " {{{
  let config = extend(
        \ get(b:, '_config', {}),
        \ get(a:000, 0, {}),
        \)
  let gita = s:get_gita()

  let result = gita.git.get_parsed_status(extend({
        \ 'no_cache': 1,
        \}, config))
  if get(result, 'status', 0)
    redraw
    call gita#utils#errormsg(
          \ printf('vim-gita: Fail: %s', join(result.args)),
          \)
    call gita#utils#infomsg(
          \ result.stdout,
          \)
    return -1
  endif

  " create statuses lines & map
  let statuses_map = {}
  let statuses_lines = []
  for status in result.all
    call add(statuses_lines, status.record)
    let statuses_map[status.record] = status
  endfor
  let gita.features.status.statuses_map = statuses_map

  " create buffer lines
  let buflines = s:L.flatten([
        \ ['# Press ?m and/or ?s to toggle a help of mapping and/or short format.'],
        \ s:get_help('status_mapping'),
        \ s:get_help('short_format'),
        \ gita#util#interface_get_misc_lines(),
        \ statuses_lines,
        \ empty(statuses_map) ? ['Nothing to commit (Working tree is clean).'] : [],
        \])

  " update content
  call gita#utils#buffer#update(buflines)
endfunction " }}}

let &cpo = s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
