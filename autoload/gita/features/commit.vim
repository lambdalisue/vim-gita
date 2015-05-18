let s:save_cpo = &cpo
set cpo&vim

let s:const = {}
let s:const.bufname = has('unix') ? 'gita:commit' : 'gita_commit'
let s:const.filetype = 'gita-commit'


" Modules
let s:P = gita#utils#import('Prelude')
let s:L = gita#utils#import('Data.List')
let s:D = gita#utils#import('Data.Dict')
let s:F = gita#utils#import('System.File')


" Private
function! s:get_gita(...) abort " {{{
  return call('gita#core#get', a:000)
endfunction " }}}
function! s:get_invoker(...) abort " {{{
  return call('gita#utils#invoker#get', a:000)
endfunction " }}}
function! s:get_statuses_map(...) abort " {{{
  return call('gita#features#status#get_statuses_map', a:000)
endfunction " }}}
function! s:set_statuses_map(...) abort " {{{
  return call('gita#features#status#set_statuses_map', a:000)
endfunction " }}}
function! s:get_statuses_within(...) abort " {{{
  return call('gita#features#status#get_statuses_within', a:000)
endfunction " }}}
function! s:get_status_header(...) abort " {{{
  return call('gita#features#status#get_status_header', a:000)
endfunction " }}}
function! s:get_status_abspath(...) abort " {{{
  return call('gita#features#status#get_status_abspath', a:000)
endfunction " }}}
function! s:smart_map(...) abort " {{{
  return call('gita#features#status#smart_map', a:000)
endfunction " }}}

function! s:open(...) abort " {{{
  let options = extend(
        \ get(b:, '_options', {}),
        \ get(a:000, 0, {}),
        \)
  let gita    = s:get_gita()
  let invoker = s:get_invoker()

  if !gita.enabled
    redraw
    call gita#utils#warn(
          \ 'Gita is not available in the current buffer.',
          \)
    call gita#utils#debugmsg(
          \ 'gita#features#status#s:open',
          \ printf('bufname: "%s"', bufname('%')),
          \ printf('cwd: "%s"', getcwd()),
          \ printf('gita: "%s"', gita),
          \)
    return
  endif

  call gita#utils#buffer#open(s:const.bufname, 'support_window', {
        \ 'opener': 'topleft 15 split',
        \ 'range': 'tabpage',
        \})
  silent execute printf('setlocal filetype=%s', s:const.filetype)

  if get(options, 'new', 0)
    let options = get(a:000, 0, {})
  endif

  " update buffer variables
  let b:_gita = gita
  let b:_options = s:Dict.omit(options, ['new'])
  call invoker.update_winnum()
  call gita#utils#invoker#set(invoker)

  " check if construction is required
  if exists('b:_constructed') && !get(g:, 'gita#debug', 0)
    return
  endif

  " construction
  setlocal buftype=acwrite bufhidden=hide noswapfile nobuflisted
  setlocal winfixwidth winfixheight

  autocmd! * <buffer>
  autocmd BufWriteCmd <buffer> call s:ac_write(expand('<amatch>'))
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
  call s:update(options)
  let b:_constructed = 1
endfunction " }}}
function! s:update(...) abort " {{{
  let options = extend(
        \ get(b:, '_options', {}),
        \ get(a:000, 0, {}),
        \)
  let gita = s:get_gita()

  let result = gita.git.get_parsed_commit(extend({
        \ 'no_cache': 1,
        \}, options))
  if get(result, 'status', 0)
    redraw
    call gita#utils#errormsg(
          \ printf('vim-gita: Fail: %s', join(result.args)),
          \)
    call gita#utils#infomsg(
          \ result.stdout,
          \)
    return
  endif

  " create statuses lines & map
  let statuses_map = {}
  let statuses_lines = []
  for status in result.all
    let line = printf('# %s', status.record)
    call add(statuses_lines, line)
    let statuses_map[line] = status
  endfor
  call s:set_statuses_map(statuses_map)

  " create a default commit message
  let commit_mode = ''
  let modified_reserved = 0
  if has_key(options, 'commitmsg_cached')
    let commitmsg = options.commitmsg_cached
    let modified_reserved = 1
    " clear temporary commitmsg
    unlet! options.commitmsg_cached
  elseif has_key(options, 'commitmsg_saved')
    let commitmsg = options.commitmsg_saved
  elseif !empty(gita.git.get_merge_head())
    let commit_mode = 'merge'
    let commitmsg = gita.git.get_merge_msg()
  elseif get(options, 'amend', 0)
    let commit_mode = 'amend'
    let commitmsg = gita.git.get_last_commitmsg()
  else
    let commitmsg = []
  endif

  " create buffer lines
  let buflines = s:L.flatten([
        \ commitmsg,
        \ ['# Press ?m and/or ?s to toggle a help of mapping and/or short format.'],
        \ gita#utils#help#get('commit_mapping'),
        \ gita#utils#help#get('short_format'),
        \ s:get_status_header(),
        \ commit_mode ==# 'merge' ? ['# This branch is in MERGE mode.'] : [],
        \ commit_mode ==# 'amend' ? ['# This branch is in AMEND mode.'] : [],
        \ statuses_lines,
        \])
  let buflines = buflines[0] =~# '\v^#' ? extend([''], buflines) : buflines

  " update content
  call gita#utils#buffer#update(buflines)
  if modified_reserved
    setlocal modified
  endif
endfunction " }}}
function! s:defmap() abort " {{{
  noremap <silent><buffer> <Plug>(gita-action-help-m)   :call <SID>action('help', { 'name': 'status_mapping' })
  noremap <silent><buffer> <Plug>(gita-action-help-s)   :call <SID>action('help', { 'name': 'short_format' })

  noremap <silent><buffer> <Plug>(gita-action-update)   :call <SID>action('update')<CR>
  noremap <silent><buffer> <Plug>(gita-action-switch)   :call <SID>action('open_status')<CR>
  noremap <silent><buffer> <Plug>(gita-action-commit)   :call <SID>action('commit')<CR>
  noremap <silent><buffer> <Plug>(gita-action-COMMIT)   :call <SID>action('commit', { 'force': 1 })<CR>
  noremap <silent><buffer> <Plug>(gita-action-open)     :call <SID>action('open', { 'opener': 'edit' })<CR>
  noremap <silent><buffer> <Plug>(gita-action-open-h)   :call <SID>action('open', { 'opener': 'botright split' })<CR>
  noremap <silent><buffer> <Plug>(gita-action-open-v)   :call <SID>action('open', { 'opener': 'botright vsplit' })<CR>
  noremap <silent><buffer> <Plug>(gita-action-diff)     :call <SID>action('diff_open', { 'opener': 'edit' })<CR>
  noremap <silent><buffer> <Plug>(gita-action-diff-h)   :call <SID>action('diff_compare', { 'opener': 'tabedit', 'vertical': 0 })<CR>
  noremap <silent><buffer> <Plug>(gita-action-diff-v)   :call <SID>action('diff_compare', { 'opener': 'tabedit', 'vertical': 1 })<CR>

  if get(g:, 'gita#features#commit#enable_default_keymap', 1)
    nmap <buffer><silent> q  :<C-u>quit<CR>
    nmap <buffer> <C-l> <Plug>(gita-action-update)
    nmap <buffer> ?m    <Plug>(gita-action-help-m)
    nmap <buffer> ?s    <Plug>(gita-action-help-s)

    nmap <buffer> cc <Plug>(gita-action-switch)
    nmap <buffer> CC <Plug>(gita-action-commit)

    nmap <buffer><expr> e <SID>smart_map('e', '<Plug>(gita-action-open)')
    nmap <buffer><expr> E <SID>smart_map('E', '<Plug>(gita-action-open-v)')
    nmap <buffer><expr> d <SID>smart_map('d', '<Plug>(gita-action-diff)')
    nmap <buffer><expr> D <SID>smart_map('D', '<Plug>(gita-action-diff-v)')
  endif
endfunction " }}}
function! s:ac_write(filename) abort " {{{
  if a:filename != expand('%:p')
    " a new filename is given. save the content to the new file
    execute 'w' . (v:cmdbang ? '!' : '') fnameescape(v:cmdarg) fnameescape(a:filename)
    return
  endif
  " cache commitmsg if it is called without quitting
  let options = get(b:, '_options', {})
  if !get(options, 'quitting', 0)
    let options.commitmsg_cached = s:get_current_commitmsg()
  endif
  setlocal nomodified
endfunction " }}}
function! s:ac_quit() abort " {{{
  " Note:
  " A vim help said the current buffer '%' may be different from the buffer
  " being unloaded <afile> in BufWinLeave autocmd but if I consider the case,
  " the code will " be more complicated thus now I simply trust that the
  " current buffer is the buffer being unloaded.
  let b:_options.quitting = 1
  call s:action_commit({}, options)
  call gita#utils#invoker#focus()
  call gita#utils#invoker#clear()
endfunction " }}}

function! s:action(name, ...) range abort " {{{
  let options  = extend(deepcopy(b:_options), get(a:000, 0, {}))
  let statuses = s:get_statuses_within(a:firstline, a:lastline)
  let args = [statuses, options]
  call call(printf('s:action_%s', a:name), args)
  call s:update()
endfunction " }}}
function! s:action_update(statuses, options) abort " {{{
  call s:update()
endfunction " }}}
function! s:action_open(...) abort " {{{
  call call('gita#features#status#action_open', a:000)
endfunction " }}}
function! s:action_help(...) abort " {{{
  call call('gita#features#status#action_help', a:000)
endfunction " }}}
function! s:action_commit(status, options) abort " {{{
  let gita = s:get_gita()
  let meta = gita.git.get_meta()
  let options = extend({ 'force': 0 }, a:options)
  let statuses_map = s:get_statuses_map()
  if empty(meta.merge_head) && empty(filter(values(statuses_map), 'v:val.is_staged'))
    redraw
    call gita#utils#warn(
          \ 'Nothing to be commited. Stage changes first.',
          \)
    return
  elseif &modified
    redraw
    call gita#utils#warn(
          \ 'You have unsaved changes on the commit message. Save the changes by ":w" command.',
          \)
    return
  endif

  let commitmsg = s:get_current_commitmsg()
  if join(commitmsg, '') =~# '\v^\s*$'
    redraw
    call gita#utils#info(
          \ 'No commit message is available (all lines start from "#" are truncated). The operation has canceled.',
          \)
    return
  endif

  " commit
  let tempfile = tempname()
  call writefile(commitmsg, tempfile)
  let args = ['commit', '--file', tempfile]
  let result = gita.git.commit(options)
  if result.status != 0
    redraw
    call gita#util#error(
          \ result.stdout,
          \ printf('Fail: %s', join(result.args)),
          \)
    return
  endif

  call gita#util#doautocmd('commit-post')
  " clear
  let b:_options = {}
  let gita.interface.commit = {}
  let gita.interface.commit.commitmsg_cached = []
  if !get(options, 'quitting', 0)
    call s:update()
  endif
  call gita#util#info(
        \ result.stdout,
        \ printf('Ok: %s', join(result.args)),
        \)
endfunction " }}}



" Public
function! gita#features#status#get_statuses_map(...) abort " {{{
  return call('s:get_statuses_map', a:000)
endfunction " }}}
function! gita#features#status#set_statuses_map(...) abort " {{{
  return call('s:set_statuses_map', a:000)
endfunction " }}}
function! gita#features#status#get_statuses_within(...) abort " {{{
  return call('s:get_statuses_within', a:000)
endfunction " }}}
function! gita#features#status#get_status_header(...) abort " {{{
  return call('s:get_status_header', a:000)
endfunction " }}}
function! gita#features#status#get_status_abspath(...) abort " {{{
  return call('s:get_status_abspath', a:000)
endfunction " }}}
function! gita#features#status#smart_map(...) abort " {{{
  return call('s:smart_map', a:000)
endfunction " }}}

" API
function! gita#features#status#open(...) abort " {{{
  call call('s:open', a:000)
endfunction " }}}
function! gita#features#status#update(...) abort " {{{
  call call('s:update', a:000)
endfunction " }}}


let &cpo = s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
