let s:save_cpoptions = &cpoptions
set cpoptions&vim

let s:L = gita#import('Data.List')
let s:D = gita#import('Data.Dict')
let s:P = gita#import('System.Filepath')
let s:F = gita#import('System.File')
let s:A = gita#import('ArgumentParser')

let s:const = {}
let s:const.bufname = 'gita%scommit'
let s:const.filetype = 'gita-commit'

let s:parser = s:A.new({
      \ 'name': 'Gita[!] commit',
      \ 'description': 'Record changes to the repository',
      \})
call s:parser.add_argument(
      \ '--window', '-w',
      \ 'Open a gita:commit window to manipulate the commit message (Default behavior)', {
      \   'deniable': 1,
      \   'default': 1,
      \ })
call s:parser.add_argument(
      \ '--untracked-files', '-u',
      \ 'show untracked files, optional modes: all, normal, no. (Default: all)', {
      \   'choices': ['all', 'normal', 'no'],
      \   'on_default': 'all',
      \ })
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
" TODO: Add more arguments

function! s:smart_map(...) abort " {{{
  return call('gita#action#smart_map', a:000)
endfunction " }}}
function! s:get_status_header(gita) abort " {{{
  let meta = a:gita.git.get_meta()
  let name = meta.local.name
  let branch = meta.local.branch_name
  let remote_name = meta.remote.name
  let remote_branch = meta.remote.branch_name
  let outgoing = a:gita.git.count_commits_ahead_of_remote()
  let incoming = a:gita.git.count_commits_behind_remote()
  let mode = a:gita.git.get_mode()
  let is_connected = !(empty(remote_name) || empty(remote_branch))

  let lines = []
  if is_connected
    call add(lines,
          \ printf('# Index and working tree status on a branch `%s/%s` <> `%s/%s`',
          \   name, branch, remote_name, remote_branch
          \))
    if outgoing > 0 && incoming > 0
      call add(lines,
            \ printf('# The branch is %d commit(s) ahead and %d commit(s) behind of `%s/%s`',
            \   outgoing, incoming, remote_name, remote_branch,
            \))
    elseif outgoing > 0
      call add(lines,
            \ printf('# The branch is %d commit(s) ahead of `%s/%s`',
            \   outgoing, remote_name, remote_branch,
            \))
    elseif incoming > 0
      call add(lines,
            \ printf('# The branch is %d commit(s) behind `%s/%s`',
            \   incoming, remote_name, remote_branch,
            \))
    endif
  else
    call add(lines,
          \ printf('# Index and working tree status on a branch `%s/%s`',
          \   name, branch
          \))
  endif
  if !empty(mode)
    call add(lines,
          \ printf('# The branch is currently in %s', mode),
          \)
  endif
  return lines
endfunction " }}}
function! s:get_current_commitmsg(...) abort " {{{
  let expr = get(a:000, 0, '%')
  let content = getbufline(expr, 1, '$')
  return filter(content, 'v:val !~# "^#"')
endfunction " }}}
function! s:commit(expr, options) abort " {{{
  let gita = gita#get(a:expr)
  " validate situation
  let statuses_map = gita#compat#getwinvar(bufwinnr(a:expr), '_gita_statuses_map', {})
  let staged_statuses = filter(values(statuses_map), 'v:val.is_staged')
  if empty(gita.git.get_merge_msg()) && empty(staged_statuses)
    " not in merge mode and nothing has been staged
    redraw
    call gita#utils#prompt#warn(
          \ 'No changes exist for commit. Stage changes first.',
          \)
    return
  elseif getbufvar(a:expr, '&modified')
    redraw
    call gita#utils#prompt#warn(
          \ 'You have unsaved changes on the commit message.',
          \ 'Save the changes by ":w" command first.',
          \)
    return
  endif

  " validate commitmsg
  let commitmsg = s:get_current_commitmsg(a:expr)
  if join(commitmsg, '') =~# '\v^\s*$'
    redraw
    call gita#utils#prompt#echo(
          \ 'No commit message is available.',
          \ 'Note that all lines start from "#" are truncated.',
          \ 'The operation will be canceled.',
          \)
    return
  endif

  " commit
  let options = extend(
        \ a:options,
        \ gita#compat#getwinvar(bufwinnr(a:expr), '_gita_options', {}),
        \)
  let options.file = tempname()
  call writefile(commitmsg, options.file)
  let result = gita#features#commit#exec(options, {
        \ 'echo': 'both',
        \})
  if result.status == 0
    let w = gita#compat#getwinvar(bufwinnr(a:expr), '')
    " remove cached commitmsg
    silent! unlet! gita.commitmsg_saved
    silent! unlet! w._gita_options.commitmsg_cached
    " reset options
    silent! unlet! w._gita_options.amend
  endif
endfunction " }}}
function! s:ac_BufWriteCmd() abort " {{{
  let new_filename = gita#utils#path#real_abspath(
        \ gita#utils#path#unix_abspath(expand('<amatch>')),
        \)
  let old_filename = gita#utils#path#real_abspath(
        \ gita#utils#path#unix_abspath(expand('%')),
        \)
  call gita#utils#prompt#debug(
        \ 'new_filename:', new_filename,
        \ 'old_filename:', old_filename,
        \)
  if new_filename !=# old_filename
    let cmd = printf('w%s %s',
          \ v:cmdbang ? '!' : '',
          \ fnameescape(new_filename),
          \)
    call gita#utils#prompt#debug(
          \ 'cmd:', cmd,
          \)
    silent! execute cmd
  else
    " cache commitmsg if it is called without quitting
    let gita = gita#get()
    let gita.commitmsg_saved = s:get_current_commitmsg()
    setlocal nomodified
    call gita#utils#prompt#info(
          \ "the commit message is saved in a local cache.",
          \)
  endif
endfunction " }}}
function! s:ac_WinLeave() abort " {{{
  if !&modified && gita#utils#prompt#asktf('Do you want to commit changes?', 'y')
    call s:commit('%', {})
  endif
endfunction " }}}

let s:actions = {}
function! s:actions.update(candidates, options, config) abort " {{{
  if !get(a:options, 'no_update')
    call gita#features#commit#update(a:options, { 'force_update': 1 })
  endif
endfunction " }}}
function! s:actions.open_status(candidates, options, config) abort " {{{
  if &modified
    let gita = gita#get()
    let gita.commitmsg_cached = s:get_current_commitmsg()
    setlocal nomodified
  endif
  call gita#features#status#open(a:options)
endfunction " }}}
function! s:actions.commit(candidates, options, config) abort " {{{
  call s:commit('%', a:options)
  call self.update(a:candidates, a:options, a:config)
endfunction " }}}


function! gita#features#commit#exec(...) abort " {{{
  let gita = gita#get()
  let options = get(a:000, 0, {})
  let config = get(a:000, 1, {})
  if gita.fail_on_disabled()
    return { 'status': -1 }
  endif
  if !empty(get(options, '--', []))
    " git understand REAL/UNIX path in working tree
    let options['--'] = gita#utils#path#real_abspath(options['--'])
  endif
  let options = s:D.pick(options, [
        \ '--',
        \ 'file',
        \ 'porcelain',
        \ 'dry_run',
        \ 'u', 'untracked_files',
        \ 'a', 'all',
        \ 'reset_author',
        \ 'amend',
        \])
  return gita.operations.commit(options, config)
endfunction " }}}
function! gita#features#commit#exec_cached(...) abort " {{{
  let gita = gita#get()
  let options = get(a:000, 0, {})
  let config = get(a:000, 1, {})
  if gita.fail_on_disabled()
    return { 'status': -1 }
  endif
  let cache_name = s:P.join('commit', string(s:D.pick(options, [
        \ '--',
        \ 'porcelain',
        \ 'u', 'untracked-files',
        \ 'a', 'all',
        \ 'amend',
        \])))
  let cached_status = gita.git.is_updated('index', 'commit') || get(config, 'force_update', 0)
        \ ? {}
        \ : gita.git.cache.repository.get(cache_name, {})
  if !empty(cached_status)
    return cached_status
  endif
  let result = gita#features#commit#exec(options, config)
  if result.status != get(config, 'success_status', 0)
    return result
  endif
  call gita.git.cache.repository.set(cache_name, result)
  return result
endfunction " }}}
function! gita#features#commit#open(...) abort " {{{
  let bufname = gita#utils#buffer#bufname(
        \ substitute(s:const.bufname, '%s', g:gita#utils#buffer#separator, 'g'),
        \)
  let result = gita#monitor#open(bufname, get(a:000, 0, {}), {
        \ 'opener': g:gita#features#commit#monitor_opener,
        \ 'range': g:gita#features#commit#monitor_range,
        \})
  if result.status
    " gita is not available
    return
  elseif result.constructed
    " the buffer has been constructed, mean that the further construction
    " is not required.
    call gita#features#commit#update({}, { 'force_update': result.loaded })
    silent execute printf("setlocal filetype=%s", s:const.filetype)
    return
  endif

  setlocal buftype=acwrite
  augroup vim-gita-commit-window
    autocmd! * <buffer>
    autocmd BufWriteCmd <buffer> call s:ac_BufWriteCmd()
  augroup END
  call gita#utils#hooks#register('ac_WinLeave', function('s:ac_WinLeave'))
  call gita#action#extend_actions(s:actions)
  call gita#features#commit#define_mappings()
  if g:gita#features#commit#enable_default_mappings
    call gita#features#commit#define_default_mappings()
  endif

  call gita#features#commit#update({}, { 'force_update': 1 })
  silent execute printf("setlocal filetype=%s", s:const.filetype)
endfunction " }}}
function! gita#features#commit#update(...) abort " {{{
  let gita = gita#get()
  let options = extend(
        \ deepcopy(w:_gita_options),
        \ get(a:000, 0, {}),
        \)
  let options.porcelain = 1
  let options.dry_run = 1
  let config = get(a:000, 1, {})
  let result = gita#features#commit#exec_cached(options, extend({
        \ 'echo': '',
        \ 'doautocmd': 0,
        \ 'success_status': 1,
        \}, config))
  if result.status != 1
    bwipe
    return
  endif
  let statuses = gita#utils#status#parse(result.stdout)

  " create statuses lines & map
  let statuses_map = {}
  let statuses_lines = []
  for status in sort(statuses.all, function('gita#utils#status#sortfn'))
    let status_record = printf('# %s', status.record)
    let statuses_map[status_record] = status
    call add(statuses_lines, status_record)
  endfor
  let w:_gita_statuses_map = statuses_map

  " reset commitmsg if 'new_commitmsg' is specified
  if get(options, 'new_commitmsg')
    silent! unlet! options.new_commitmsg
    silent! unlet! w:_gita_options.new_commitmsg
    silent! unlet! gita.commitmsg_saved
    silent! unlet! gita.commitmsg_cached
  endif

  " create a default commit message
  let commit_mode = ''
  let modified_reserved = 0
  if has_key(gita, 'commitmsg_cached')
    let commitmsg = gita.commitmsg_cached
    let modified_reserved = 1
    " clear temporary commitmsg
    unlet! gita.commitmsg_cached
  elseif has_key(gita, 'commitmsg_saved')
    let commitmsg = gita.commitmsg_saved
  elseif !empty(gita.git.get_merge_msg())
    let commit_mode = 'merge'
    let commitmsg = gita.git.get_merge_msg()
  elseif get(options, 'amend')
    let commit_mode = 'amend'
    let commitmsg = gita.git.get_last_commitmsg()
  else
    let commitmsg = []
  endif

  " update content
  let buflines = s:L.flatten([
        \ commitmsg,
        \ '# Press ?m and/or ?s to toggle a help of mapping and/or short format.',
        \ gita#utils#help#get('commit_mapping'),
        \ gita#utils#help#get('short_format'),
        \ s:get_status_header(gita),
        \ commit_mode ==# 'merge' ? ['# This branch is in MERGE mode.'] : [],
        \ commit_mode ==# 'amend' ? ['# This branch is in AMEND mode.'] : [],
        \ statuses_lines,
        \])
  let buflines = buflines[0] =~# '\v^#' ? extend([''], buflines) : buflines
  call gita#utils#buffer#update(buflines)
  if modified_reserved
    setlocal modified
  endif
endfunction " }}}
function! gita#features#commit#define_mappings() abort " {{{
  call gita#monitor#define_mappings()

  noremap <silent><buffer> <Plug>(gita-action-help-m)
        \ :<C-u>call gita#action#call('help', { 'name': 'commit_mapping' })<CR>

  noremap <silent><buffer> <Plug>(gita-action-update)
        \ :<C-u>call gita#action#call('update')<CR>

  noremap <silent><buffer> <Plug>(gita-action-switch)
        \ :<C-u>call gita#action#call('open_status')<CR>
  noremap <silent><buffer> <Plug>(gita-action-commit)
        \ :<C-u>call gita#action#call('commit')<CR>
endfunction " }}}
function! gita#features#commit#define_default_mappings() abort " {{{
  call gita#monitor#define_default_mappings()

  nmap <buffer> <C-l> <Plug>(gita-action-update)

  nmap <buffer> cc <Plug>(gita-action-switch)
  nmap <buffer> CC <Plug>(gita-action-commit)
endfunction " }}}
function! gita#features#commit#command(bang, range, ...) abort " {{{
  let options = s:parser.parse(a:bang, a:range, get(a:000, 0, ''))
  if !empty(options)
    let options = extend(
          \ deepcopy(g:gita#features#commit#default_options),
          \ options)
    if get(options, 'window')
      call gita#features#commit#open(options)
    else
      call gita#features#commit#exec(options)
    endif
  endif
endfunction " }}}
function! gita#features#commit#complete(arglead, cmdline, cursorpos) abort " {{{
  return s:parser.complete(a:arglead, a:cmdline, a:cursorpos)
endfunction " }}}
function! gita#features#commit#define_highlights() abort " {{{
  call gita#features#status#define_highlights()
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
  syntax match GitaImportant  /\vREBASE-[mi] \d\/\d/
  syntax match GitaImportant  /\vREBASE \d\/\d/
  syntax match GitaImportant  /\vAM \d\/\d/
  syntax match GitaImportant  /\vAM\/REBASE \d\/\d/
  syntax match GitaImportant  /\v(MERGING|CHERRY-PICKING|REVERTING|BISECTING)/
  syntax match GitaImportant  /\v(AMEND|MERGE)/
endfunction " }}}


let &cpoptions = s:save_cpoptions
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
