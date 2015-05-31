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
let s:A = gita#utils#import('ArgumentParser')


" Private
function! s:get_parser() abort " {{{
  if !exists('s:parser') || get(g:, 'gita#debug', 0)
    let s:parser = s:A.new({
          \ 'name': 'Record changes to the repository via Gita interface',
          \})
    call s:parser.add_argument(
          \ '--all', '-a',
          \ 'commit all changed files',
          \)
    call s:parser.add_argument(
          \ '--reset-author',
          \ 'the commit is authored by me now (used with -C/-c/--amend)',
          \)
    call s:parser.add_argument(
          \ '--amend',
          \ 'amend previous commit',
          \)
    call s:parser.add_argument(
          \ '--untracked-files', '-u',
          \ 'show untracked files, optional modes: all, normal, no. (Default: all)', {
          \   'choices': ['all', 'normal', 'no'],
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
function! s:get_current_commitmsg() abort " {{{
  return filter(getline(1, '$'), 'v:val !~# "^#"')
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
          \ printf('gita: "%s"', string(gita)),
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
endfunction " }}}
function! s:update(...) abort " {{{
  let options = extend(
        \ get(w:, '_gita_options', {}),
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
        \ s:get_status_header(gita),
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
  noremap <silent><buffer> <Plug>(gita-action-help-m)   :call <SID>action('help', { 'name': 'commit_mapping' })<CR>
  noremap <silent><buffer> <Plug>(gita-action-help-s)   :call <SID>action('help', { 'name': 'short_format' })<CR>

  noremap <silent><buffer> <Plug>(gita-action-update)   :call <SID>action('update')<CR>
  noremap <silent><buffer> <Plug>(gita-action-switch)   :call <SID>action('open_status')<CR>
  noremap <silent><buffer> <Plug>(gita-action-commit)   :call <SID>action('commit')<CR>
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
  let options = get(w:, '_gita_options', {})
  if !get(options, 'quitting', 0)
    let options.commitmsg_saved = s:get_current_commitmsg()
  endif
  setlocal nomodified
endfunction " }}}
function! s:ac_quit() abort " {{{
  " Note:
  " A vim help said the current buffer '%' may be different from the buffer
  " being unloaded <afile> in BufWinLeave autocmd but if I consider the case,
  " the code will " be more complicated thus now I simply trust that the
  " current buffer is the buffer being unloaded.
  let w:_gita_options = extend(w:_gita_options, {
        \ 'quitting': 1,
        \})
  call s:action_commit({}, w:_gita_options)
  call gita#utils#invoker#focus()
  call gita#utils#invoker#clear()
endfunction " }}}

function! s:action(name, ...) range abort " {{{
  let update_required_action_pattern = printf('^\%%(%s\)', join([
        \ 'help',
        \ 'commit',
        \], '\|'))
  let options  = extend(deepcopy(w:_gita_options), get(a:000, 0, {}))
  let statuses = s:get_statuses_within(a:firstline, a:lastline)
  let args = [statuses, options]
  call call(printf('s:action_%s', a:name), args)
  if a:name =~# update_required_action_pattern && !get(options, 'quitting')
    call s:update()
  endif
endfunction " }}}
function! s:action_update(statuses, options) abort " {{{
  call s:update(a:options)
endfunction " }}}
function! s:action_open_status(status, options) abort " {{{
  if &modified
    let b:_gita_options.commitmsg_cached = s:get_current_commitmsg()
    setlocal nomodified
  endif
  call gita#features#status#open(a:options)
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
function! s:action_commit(statuses, options) abort " {{{
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
  if get(options, 'amend', 0)
    let args = args + ['--amend']
  endif
  let result = gita.exec(args)
  if result.status == 0
    let w:_gita_options = { 'new': 1 }
    call gita#utils#info(result.stdout)
  endif
endfunction " }}}


" Internal API
function! gita#features#commit#open(...) abort " {{{
  call call('s:open', a:000)
endfunction " }}}
function! gita#features#commit#update(...) abort " {{{
  call call('s:update', a:000)
endfunction " }}}
function! gita#features#commit#define_highlights() abort " {{{
  call gita#features#status#define_highlights()
  " github
  highlight default link GitaGitHubKeyword Keyword
  highlight default link GitaGitHubIssue   Define
endfunction " }}}
function! gita#features#commit#define_syntax() abort " {{{
  syntax match GitaStaged     /\v^# [ MADRC][ MD]/hs=s+2,he=e-1 contains=ALL
  syntax match GitaUnstaged   /\v^# [ MADRC][ MD]/hs=s+3 contains=ALL
  syntax match GitaStaged     /\v^# [ MADRC]\s.*$/hs=s+5 contains=ALL
  syntax match GitaUnstaged   /\v^# .[MDAU?].*$/hs=s+5 contains=ALL
  syntax match GitaIgnored    /\v^# \!\!\s.*$/hs=s+2
  syntax match GitaUntracked  /\v^# \?\?\s.*$/hs=s+2
  syntax match GitaConflicted /\v^# %(DD|AU|UD|UA|DU|AA|UU)\s.*$/hs=s+2
  syntax match GitaComment    /\v^#.*$/ contains=ALL
  syntax match GitaBranch     /\v`[^`]{-}`/hs=s+1,he=e-1
  syntax keyword GitaImportant AMEND MERGE
  " github
  syntax keyword GitaGitHubKeyword close closes closed fix fixes fixed resolve resolves resolved
  syntax match   GitaGitHubIssue   '\v%([^ /#]+/[^ /#]+#\d+|#\d+)'
endfunction " }}}


" External API
function! gita#features#commit#command(bang, range, ...) abort " {{{
  let parser = s:get_parser()
  let opts = parser.parse(a:bang, a:range, get(a:000, 0, ''))
  if !empty(opts)
    call s:open(opts)
  endif
endfunction " }}}
function! gita#features#commit#complete(arglead, cmdline, cursorpos) abort " {{{
  let parser = s:get_parser()
  let candidates = parser.complete(a:arglead, a:cmdline, a:cursorpos)
  return candidates
endfunction " }}}


let &cpo = s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
