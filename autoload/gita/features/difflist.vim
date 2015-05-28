let s:save_cpo = &cpo
set cpo&vim
let s:const = {}
let s:const.bufname = has('unix') ? 'gita:difflist' : 'gita_difflist'
let s:const.filetype = 'gita-difflist'


" Modules
let s:P = gita#utils#import('Prelude')
let s:L = gita#utils#import('Data.List')
let s:D = gita#utils#import('Data.Dict')
let s:F = gita#utils#import('System.File')
let s:S = gita#utils#import('VCS.Git.StatusParser')
let s:A = gita#utils#import('ArgumentParser')


" Private
function! s:get_parser() abort " {{{
  if !exists('s:parser') || get(g:, 'gita#debug', 0)
    let s:parser = s:A.new({
          \ 'name': 'Gita show',
          \ 'description': 'Show files changed from a specified commit in Gita interface',
          \})
    call s:parser.add_argument(
          \ 'commit',
          \ 'show untracked files, optional modes: all, normal, no. (Default: all)', {
          \   'required': 1,
          \ })
    call s:parser.add_argument(
          \ '--untracked-files', '-u',
          \ 'show untracked files, optional modes: all, normal, no. (Default: all)', {
          \   'choices': ['all', 'normal', 'no'],
          \   'default': 'all',
          \ })
    call s:parser.add_argument(
          \ '--ignore-submodules',
          \ 'ignore changes to submodules, optional when: all, dirty, untracked (Default: all)', {
          \   'choices': ['all', 'dirty', 'untracked'],
          \   'default': 'all',
          \ })
  endif
  return s:parser
endfunction " }}}

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
        \ get(w:, '_gita_options', {}),
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

  let bufname = printf('%s:%s',
        \ s:const.bufname,
        \ get(options, 'commit', 'INDEX')
        \)
  call gita#utils#buffer#open(bufname, 'support_window', {
        \ 'opener': 'topleft 15 split',
        \ 'range': 'tabpage',
        \})
  silent execute printf('setlocal filetype=%s', s:const.filetype)

  if get(options, 'new', 0)
    let options = get(a:000, 0, {})
  endif

  " update buffer variables
  let w:_gita = gita
  let w:_gita_options = s:D.omit(options, [
        \ 'new'
        \])
  call invoker.update_winnum()
  call gita#utils#invoker#set(invoker)

  " check if construction is required
  if get(b:, '_gita_constructed') && !get(g:, 'gita#debug', 0)
    call s:update(options)
    return
  endif
  let b:_gita_constructed = 1

  " construction
  setlocal buftype=nofile bufhidden=hide noswapfile nobuflisted
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
endfunction " }}}
function! s:update(...) abort " {{{
  let options = extend(
        \ get(w:, '_gita_options', {}),
        \ get(a:000, 0, {}),
        \)
  let gita = s:get_gita()

  let args = filter([
        \ 'diff',
        \ '--no-prefix',
        \ '--no-color',
        \ '--name-status',
        \ get(options, 'commit', ''),
        \], '!empty(v:val)')
  let result = gita.exec(args)
  if result.status != 0
    return
  endif
  let statuses = s:S.parse(substitute(result.stdout, '\t', '  ', 'g'))

  " create statuses lines & map
  let statuses_map = {}
  let statuses_lines = []
  for status in statuses.all
    let line = printf('%s', status.record)
    call add(statuses_lines, line)
    let statuses_map[line] = status
  endfor
  call s:set_statuses_map(statuses_map)

  " create buffer lines
  let buflines = s:L.flatten([
        \ ['# Press ?m and/or ?s to toggle a help of mapping and/or short format.'],
        \ gita#utils#help#get('difflist_mapping'),
        \ gita#utils#help#get('short_format'),
        \ statuses_lines,
        \])

  " update content
  call gita#utils#buffer#update(buflines)
endfunction " }}}
function! s:defmap() abort " {{{
  noremap <silent><buffer> <Plug>(gita-action-help-m)   :call <SID>action('help', { 'name': 'difflist_mapping' })<CR>
  noremap <silent><buffer> <Plug>(gita-action-help-s)   :call <SID>action('help', { 'name': 'short_format' })<CR>

  noremap <silent><buffer> <Plug>(gita-action-update)   :call <SID>action('update')<CR>
  noremap <silent><buffer> <Plug>(gita-action-open)     :call <SID>action('open')<CR>
  noremap <silent><buffer> <Plug>(gita-action-open-h)   :call <SID>action('open', { 'opener': 'botright split' })<CR>
  noremap <silent><buffer> <Plug>(gita-action-open-v)   :call <SID>action('open', { 'opener': 'botright vsplit' })<CR>
  noremap <silent><buffer> <Plug>(gita-action-diff)     :call <SID>action('diff_open')<CR>
  noremap <silent><buffer> <Plug>(gita-action-diff-h)   :call <SID>action('diff_diff', { 'vertical': 0 })<CR>
  noremap <silent><buffer> <Plug>(gita-action-diff-v)   :call <SID>action('diff_diff', { 'vertical': 1 })<CR>

  if get(g:, 'gita#features#commit#enable_default_keymap', 1)
    nmap <buffer><silent> q  :<C-u>quit<CR>
    nmap <buffer> <C-l> <Plug>(gita-action-update)
    nmap <buffer> ?m    <Plug>(gita-action-help-m)
    nmap <buffer> ?s    <Plug>(gita-action-help-s)

    nmap <buffer><expr> e <SID>smart_map('e', '<Plug>(gita-action-open)')
    nmap <buffer><expr> E <SID>smart_map('E', '<Plug>(gita-action-open-v)')
    nmap <buffer><expr> d <SID>smart_map('d', '<Plug>(gita-action-diff)')
    nmap <buffer><expr> D <SID>smart_map('D', '<Plug>(gita-action-diff-v)')
  endif
endfunction " }}}
function! s:ac_quit() abort " {{{
  " Note:
  " A vim help said the current buffer '%' may be different from the buffer
  " being unloaded <afile> in BufWinLeave autocmd but if I consider the case,
  " the code will " be more complicated thus now I simply trust that the
  " current buffer is the buffer being unloaded.
  call gita#utils#invoker#focus()
  call gita#utils#invoker#clear()
endfunction " }}}

function! s:action(name, ...) range abort " {{{
  let update_required_action_pattern = printf('^\%%(%s\)', join([
        \ 'help',
        \], '\|'))
  let options  = extend(deepcopy(w:_gita_options), get(a:000, 0, {}))
  let statuses = s:get_statuses_within(a:firstline, a:lastline)
  let args = [statuses, options]
  call call(printf('s:action_%s', a:name), args)
  if a:name =~# update_required_action_pattern
    call s:update()
  endif
endfunction " }}}
function! s:action_update(statuses, options) abort " {{{
  call s:update(a:options)
endfunction " }}}
function! s:action_open(...) abort " {{{
  call call('gita#features#status#action_open', a:000)
endfunction " }}}
function! s:action_diff_open(...) abort " {{{
  call call('gita#features#status#action_diff_open', a:000)
endfunction " }}}
function! s:action_diff_diff(...) abort " {{{
  call call('gita#features#status#action_diff_diff', a:000)
endfunction " }}}
function! s:action_help(...) abort " {{{
  call call('gita#features#status#action_help', a:000)
endfunction " }}}


" Internal API
function! gita#features#difflist#open(...) abort " {{{
  call call('s:open', a:000)
endfunction " }}}
function! gita#features#difflist#update(...) abort " {{{
  call call('s:update', a:000)
endfunction " }}}
function! gita#features#difflist#define_highlights() abort " {{{
  call gita#features#status#define_highlights()
endfunction " }}}
function! gita#features#difflist#define_syntax() abort " {{{
  call gita#features#status#define_syntax()
endfunction " }}}

" External API
function! gita#features#difflist#command(bang, range, ...) abort " {{{
  let parser = s:get_parser()
  let opts = parser.parse(a:bang, a:range, get(a:000, 0, ''))
  if !empty(opts)
    call s:open(opts)
  endif
endfunction " }}}
function! gita#features#difflist#complete(arglead, cmdline, cursorpos) abort " {{{
  let parser = s:get_parser()
  let candidates = parser.complete(a:arglead, a:cmdline, a:cursorpos)
  return candidates
endfunction " }}}

let &cpo = s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
