let s:save_cpo = &cpo
set cpo&vim

let s:const = {}
let s:const.bufname = has('unix') ? 'gita:commit' : 'gita_commit'
let s:const.filetype = 'gita-status'


" Modules
let s:P = gita#utils#import('Prelude')
let s:L = gita#utils#import('Data.List')
let s:F = gita#utils#import('System.File')
let s:A = gita#utils#import('ArgumentParser')


" Private functions
function! s:get_gita(...) abort " {{{
  return call('gita#core#get', a:000)
endfunction " }}}
function! s:smart_map(...) abort " {{{
  return call('gita#utils#status#smart_map', a:000)
endfunction " }}}
function! s:get_current_commitmsg() abort " {{{
  return filter(getline(1, '$'), 'v:val !~# "^#"')
endfunction " }}}

function! s:open(...) abort " {{{
  let options = extend(
        \ get(b:, '_options', {}),
        \ get(a:000, 0, {}),
        \)
  let gita = s:get_gita()
  let invoker = gita#utils#invoker#get()

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

  " update buffer variables
  let b:_gita = gita
  let b:_options = options
  call gita#utils#invoker#set(invoker)
  call invoker.update_winnum()

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
  call s:update(options)
  let b:_constructed = 1
  return ret.bufnr
endfunction " }}}
function! s:update(...) abort " {{{
  let options = extend(
        \ get(b:, '_options', {}),
        \ get(a:000, 0, {}),
        \)
  let gita = s:get_gita()

  let result = gita.git.get_parsed_status(extend({
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
    return -1
  endif

  " create statuses lines & map
  let statuses_map = {}
  let statuses_lines = []
  for status in result.all
    call add(statuses_lines, status.record)
    let statuses_map[status.record] = status
  endfor
  call gita#utils#status#set_statuses_map(statuses_map)

  " create buffer lines
  let buflines = s:L.flatten([
        \ ['# Press ?m and/or ?s to toggle a help of mapping and/or short format.'],
        \ gita#utils#help#get('status_mapping'),
        \ gita#utils#help#get('short_format'),
        \ gita#utils#status#get_status_header(),
        \ statuses_lines,
        \ empty(statuses_map) ? ['Nothing to commit (Working tree is clean).'] : [],
        \])

  " update content
  call gita#utils#buffer#update(buflines)
endfunction " }}}
function! s:defmap() abort " {{{
  noremap <silent><buffer> <Plug>(gita-action-help-m)   :call <SID>action('help', { 'name': 'status_mapping' })
  noremap <silent><buffer> <Plug>(gita-action-help-s)   :call <SID>action('help', { 'name': 'short_format' })

  noremap <silent><buffer> <Plug>(gita-action-update)   :call <SID>action('update')<CR>
  noremap <silent><buffer> <Plug>(gita-action-switch)   :call <SID>action('open_commit')<CR>
  noremap <silent><buffer> <Plug>(gita-action-commit)   :call <SID>action('open_commit', { 'new': 1, 'amend': 0 })<CR>
  noremap <silent><buffer> <Plug>(gita-action-commit-a) :call <SID>action('open_commit', { 'new': 1, 'amend': 1 })<CR>
  noremap <silent><buffer> <Plug>(gita-action-open)     :call <SID>action('open', { 'opener': 'edit' })<CR>
  noremap <silent><buffer> <Plug>(gita-action-open-h)   :call <SID>action('open', { 'opener': 'botright split' })<CR>
  noremap <silent><buffer> <Plug>(gita-action-open-v)   :call <SID>action('open', { 'opener': 'botright vsplit' })<CR>
  noremap <silent><buffer> <Plug>(gita-action-diff)     :call <SID>action('diff_open', { 'opener': 'edit' })<CR>
  noremap <silent><buffer> <Plug>(gita-action-diff-h)   :call <SID>action('diff_compare', { 'vertical': 0 })<CR>
  noremap <silent><buffer> <Plug>(gita-action-diff-v)   :call <SID>action('diff_compare', { 'vertical': 1 })<CR>
  noremap <silent><buffer> <Plug>(gita-action-solve2-h) :call <SID>action('solve2', { 'vertical': 0 })<CR>
  noremap <silent><buffer> <Plug>(gita-action-solve2-v) :call <SID>action('solve2', { 'vertical': 1 })<CR>
  noremap <silent><buffer> <Plug>(gita-action-solve3-h) :call <SID>action('solve3', { 'vertical': 0 })<CR>
  noremap <silent><buffer> <Plug>(gita-action-solve3-v) :call <SID>action('solve3', { 'vertical': 1 })<CR>

  noremap <silent><buffer> <Plug>(gita-action-add)      :call <SID>action('add')<CR>
  noremap <silent><buffer> <Plug>(gita-action-ADD)      :call <SID>action('add', { 'force': 1 })<CR>
  noremap <silent><buffer> <Plug>(gita-action-rm)       :call <SID>action('rm')<CR>
  noremap <silent><buffer> <Plug>(gita-action-RM)       :call <SID>action('RM', { 'force': 1 })<CR>
  noremap <silent><buffer> <Plug>(gita-action-reset)    :call <SID>action('reset')<CR>
  noremap <silent><buffer> <Plug>(gita-action-checkout) :call <SID>action('checkout')<CR>
  noremap <silent><buffer> <Plug>(gita-action-CHECKOUT) :call <SID>action('checkout', { 'force': 1 })<CR>
  noremap <silent><buffer> <Plug>(gita-action-ours)     :call <SID>action('ours')<CR>
  noremap <silent><buffer> <Plug>(gita-action-theirs)   :call <SID>action('theirs')<CR>
  noremap <silent><buffer> <Plug>(gita-action-stage)    :call <SID>action('stage')<CR>
  noremap <silent><buffer> <Plug>(gita-action-unstage)  :call <SID>action('unstage')<CR>
  noremap <silent><buffer> <Plug>(gita-action-toggle)   :call <SID>action('toggle')<CR>
  noremap <silent><buffer> <Plug>(gita-action-discard)  :call <SID>action('discard')<CR>

  if get(g:, 'gita#commands#status#enable_default_keymap', 1)
    nmap <buffer><silent> q  :<C-u>quit<CR>
    nmap <buffer> <C-l> <Plug>(gita-action-update)

    nmap <buffer> ?m <Plug>(gita-action-help-m)
    nmap <buffer> ?s <Plug>(gita-action-help-s)

    nmap <buffer> cc <Plug>(gita-action-switch)
    nmap <buffer> cC <Plug>(gita-action-commit)
    nmap <buffer> cA <Plug>(gita-action-commit-a)

    nmap <buffer><expr> e  <SID>smart_map('e', '<Plug>(gita-action-open)')
    nmap <buffer><expr> E  <SID>smart_map('E', '<Plug>(gita-action-open-v)')
    nmap <buffer><expr> d  <SID>smart_map('d', '<Plug>(gita-action-diff)')
    nmap <buffer><expr> D  <SID>smart_map('D', '<Plug>(gita-action-diff-v)')
    nmap <buffer><expr> s  <SID>smart_map('s', '<Plug>(gita-action-solve2-v)')
    nmap <buffer><expr> S  <SID>smart_map('S', '<Plug>(gita-action-solve3-v)')

    " operation
    nmap <buffer><expr> << <SID>smart_map('<<', '<Plug>(gita-action-stage)')
    nmap <buffer><expr> >> <SID>smart_map('>>', '<Plug>(gita-action-unstage)')
    nmap <buffer><expr> -- <SID>smart_map('--', '<Plug>(gita-action-toggle)')
    nmap <buffer><expr> == <SID>smart_map('==', '<Plug>(gita-action-discard)')

    " raw operation
    nmap <buffer><expr> -a <SID>smart_map('-a', '<Plug>(gita-action-add)')
    nmap <buffer><expr> -A <SID>smart_map('-A', '<Plug>(gita-action-ADD)')
    nmap <buffer><expr> -r <SID>smart_map('-r', '<Plug>(gita-action-reset)')
    nmap <buffer><expr> -d <SID>smart_map('-d', '<Plug>(gita-action-rm)')
    nmap <buffer><expr> -D <SID>smart_map('-D', '<Plug>(gita-action-RM)')
    nmap <buffer><expr> -c <SID>smart_map('-c', '<Plug>(gita-action-checkout)')
    nmap <buffer><expr> -C <SID>smart_map('-C', '<Plug>(gita-action-CHECKOUT)')
    nmap <buffer><expr> -o <SID>smart_map('-o', '<Plug>(gita-action-ours)')
    nmap <buffer><expr> -t <SID>smart_map('-t', '<Plug>(gita-action-theirs)')

    vmap <buffer> << <Plug>(gita-action-stage)
    vmap <buffer> >> <Plug>(gita-action-unstage)
    vmap <buffer> -- <Plug>(gita-action-toggle)
    vmap <buffer> == <Plug>(gita-action-discard)

    vmap <buffer> -a <Plug>(gita-action-add)
    vmap <buffer> -A <Plug>(gita-action-ADD)
    vmap <buffer> -r <Plug>(gita-action-reset)
    vmap <buffer> -d <Plug>(gita-action-rm)
    vmap <buffer> -D <Plug>(gita-action-RM)
    vmap <buffer> -c <Plug>(gita-action-checkout)
    vmap <buffer> -C <Plug>(gita-action-CHECKOUT)
    vmap <buffer> -o <Plug>(gita-action-ours)
    vmap <buffer> -t <Plug>(gita-action-theirs)
  endif
endfunction " }}}
function! s:ac_quit() abort " {{{
  let invoker = gita#utils#invoker#get()
  call invoker.focus()
  call gita#utils#invoker#clear()
endfunction " }}}

function! s:action(name, ...) range abort " {{{
  let options  = extend(deepcopy(b:_options), get(a:000, 0, {}))
  let statuses = gita#utils#status#get_selected_statuses(a:firstline, a:lastline)
  let args = [statuses, options]
  call call(printf('s:action_%s', a:name), args)
  call s:update()
endfunction " }}}
function! s:action_update(statuses, options) abort " {{{
  call s:update()
endfunction " }}}
function! s:action_open(statuses, options) abort " {{{
  call gita#utils#status#action_open(a:statuses, a:options)
endfunction " }}}
function! s:action_help(statuses, options) abort " {{{
  call gita#utils#status#help(a:statuses, a:options)
endfunction " }}}
function! s:action_commit(status, options) abort " {{{
  let gita = s:get_gita()
  let meta = gita.git.get_meta()
  let options = extend({ 'force': 0 }, a:options)
  let statuses_map = gita#utils#status#get_statuses_map()
  if empty(meta.merge_head) && empty(filter(values(statuses_map), 'v:val.is_staged'))
    redraw | call gita#utils#info(
          \ 'Nothing to be commited. Stage changes first.',
          \)
    return
  elseif &modified
    redraw | call gita#utils#warn(
          \ 'You have unsaved changes on the commit message.',
          \ 'Save the changes by ":w" command.',
          \)
    return
  endif

  let commitmsg = s:get_current_commitmsg()
  if join(commitmsg, '') =~# '\v^\s*$'
    redraw | call gita#utils#info(
          \ 'No commit message is available (all lines start from "#" are truncated).',
          \ 'The operation has canceled.',
          \)
    return
  endif

  " commit
  let options.file = tempname()
  call writefile(commitmsg, options.file)
  let result = gita.git.commit(options)
  if result.status != 0
    redraw | call gita#utils#error(
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

function! s:get_parser() abort " {{{
  if !exists('s:parser') || get(g:, 'gita#debug', 0)
    let s:parser = s:A.new({
          \ 'name': 'Gita status',
          \ 'description': 'show the working tree status in Gita interface',
          \})
    let t = s:A.types
    call s:parser.add_argument(
          \ '--untracked-files', '-u',
          \ 'show untracked files, optional modes: all, normal, no. (Default: all)', {
          \   'choices': ['all', 'normal', 'no'],
          \   'default': 'all',
          \ })
    call s:parser.add_argument(
          \ '--ignored',
          \ 'show ignored files',
          \)
    call s:parser.add_argument(
          \ '--ignore-submodules',
          \ 'ignore changes to submodules, optional when: all, dirty, untracked (Default: all)', {
          \   'choices': ['all', 'dirty', 'untracked'],
          \   'default': 'all',
          \})
  endif
  return s:parser
endfunction " }}}
function! s:parse(...) abort " {{{
  let parser = s:get_parser()
  return call(parser.parse, a:000, parser)
endfunction " }}}


" Public function
function! gita#commands#status#open(...) abort " {{{
  call call('s:open', a:000)
endfunction " }}}
function! gita#commands#status#update(...) abort " {{{
  call call('s:update', a:000)
endfunction " }}}


let &cpo = s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
