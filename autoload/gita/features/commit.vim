let s:save_cpo = &cpo
set cpo&vim

let s:L = gita#utils#import('Data.List')
let s:D = gita#utils#import('Data.Dict')
let s:P = gita#utils#import('System.Filepath')
let s:F = gita#utils#import('System.File')
let s:S = gita#utils#import('VCS.Git.StatusParser')
let s:A = gita#utils#import('ArgumentParser')

let s:logger = gita#logging#of(expand('<sfile>'))

let s:const = {}
let s:const.bufname_sep = has('unix') ? ':' : '-'
let s:const.bufname = join(['gita', 'commit'], s:const.bufname_sep)
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
  let name = fnamemodify(a:gita.git.worktree, ':t')
  let branch = meta.current_branch
  let remote_name = meta.current_branch_remote
  let remote_branch = meta.current_remote_branch
  let outgoing = a:gita.git.count_commits_ahead_of_remote()
  let incoming = a:gita.git.count_commits_behind_remote()
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
  return lines
endfunction " }}}
function! s:get_current_commitmsg(...) abort " {{{
  let expr = get(a:000, 0, '%')
  let content = getbufline(expr, 1, '$')
  return filter(content, 'v:val !~# "^#"')
endfunction " }}}
function! s:commit(expr, options) abort " {{{
  let gita = gita#get(a:expr)
  let meta = gita.git.get_meta()
  " validate situation
  let statuses_map = getwinvar(bufwinnr(a:expr), '_gita_statuses_map', {})
  let staged_statuses = filter(values(statuses_map), 'v:val.is_staged')
  if empty(meta.merge_head) && empty(staged_statuses)
    " not in merge mode and nothing has been staged
    redraw
    call gita#utils#warn(
          \ 'No changes exist for commit. Stage changes first.',
          \)
    return
  elseif getbufvar(a:expr, '&modified')
    redraw
    call gita#utils#warn(
          \ 'You have unsaved changes on the commit message.',
          \ 'Save the changes by ":w" command first.',
          \)
    return
  endif

  " validate commitmsg
  let commitmsg = s:get_current_commitmsg(a:expr)
  if join(commitmsg, '') =~# '\v^\s*$'
    redraw
    call gita#utils#info(
          \ 'No commit message is available.'
          \ 'Note that all lines start from "#" are truncated.'
          \ 'The operation will be canceled.',
          \)
    return
  endif

  " commit
  let options = extend(
        \ a:options,
        \ getwinvar(bufwinnr(a:expr), '_gita_options', {}),
        \)
  let options.file = tempname()
  call writefile(commitmsg, options.file)
  let result = gita#features#commit#exec(options, {
        \ 'echo': 'both',
        \})
  if result.status == 0
    let w = getwinvar(bufwinnr(a:expr), '')
    " remove cached commitmsg
    silent! unlet! gita.commitmsg_saved
    silent! unlet! w._gita_options.commitmsg_cached
    " reset options
    silent! unlet! w._gita_options.amend
  endif
endfunction " }}}
function! s:ac_BufWriteCmd() abort " {{{
  let new_filename = fnamemodify(expand('<amatch>'), ':p')
  let old_filename = fnamemodify(expand('<afile>'), ':p')
  if new_filename !=# old_filename
    execute printf('w%s %s %s',
          \ v:cmdbang ? '!' : '',
          \ fnameescape(v:cmdarg),
          \ fnameescape(new_filename),
          \)
  else
    " cache commitmsg if it is called without quitting
    let gita = gita#get()
    let gita.commitmsg_saved = s:get_current_commitmsg()
    setlocal nomodified
    call gita#utils#title(
          \ "the commit message is saved in a local cache.",
          \)
  endif
endfunction " }}}

let s:actions = {}
function! s:actions.update(statuses, options) abort " {{{
  call gita#features#commit#update(a:options, { 'force_update': 1 })
endfunction " }}}
function! s:actions.open_status(statuses, options) abort " {{{
  if &modified
    let gita = gita#get()
    let gita.commitmsg_cached = s:get_current_commitmsg()
    setlocal nomodified
  endif
  call gita#features#status#open(a:options)
endfunction " }}}
function! s:actions.commit(statuses, options) abort " {{{
  call s:commit('%', a:options)
  call self.update(a:statuses, a:options)
endfunction " }}}


function! gita#features#commit#exec(...) abort " {{{
  let gita = gita#get()
  let options = get(a:000, 0, {})
  let config = get(a:000, 1, {})
  if gita.fail_on_disabled()
    return { 'status': -1 }
  endif
  if !empty(get(options, '--', []))
    call map(options['--'], 'gita#utils#expand(v:val)')
  endif
  let options = s:D.pick(options, [
        \ '--',
        \ 'file',
        \ 'porcelain',
        \ 'dry_run', 'no_status',
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
        \ 'u', 'untracked_files',
        \ 'a', 'all',
        \ 'amend',
        \])))
  let cached_status = gita.git.is_updated('index', 'commit') || get(config, 'force_update', 0)
        \ ? {}
        \ : gita.git.cache.repository.get(cache_name, {})
  if !empty(cached_status)
    return cached_status
  endif
  call s:logger.debug('No cached status is found (%s)', expand('<sfile>'))
  let result = gita#features#commit#exec(options, config)
  if result.status != get(config, 'success_status', 0)
    return result
  endif
  call gita.git.cache.repository.set(cache_name, result)
  return result
endfunction " }}}
function! gita#features#commit#open(...) abort " {{{
  let enable_default_mappings = g:gita#features#commit#enable_default_mappings
  let result = gita#display#open(s:const.bufname, get(a:000, 0, {}), {
        \ 'enable_default_mappings': enable_default_mappings,
        \})
  if result.status == -1
    " gita is not available
    return
  elseif result.status == 1
    " the buffer is already constructed
    call gita#features#commit#update({}, { 'force_update': result.loaded })
    silent execute printf("setlocal filetype=%s", s:const.filetype)
    return
  endif
  call gita#action#extend_actions(s:actions)

  " Define hooks
  function! b:_gita_hooks.ac_WinLeave_pre() abort
    if !&modified && gita#utils#asktf('Do you want to commit changes?', 'y')
      call s:commit('%', {})
    endif
  endfunction

  " Define options and extra AutoCmd
  setlocal buftype=acwrite
  augroup vim-gita-commit-window
    autocmd! * <buffer>
    autocmd BufWriteCmd <buffer> call s:ac_BufWriteCmd()
  augroup END

  " Define extra Plug key mappings
  noremap <silent><buffer> <Plug>(gita-action-help-m)
        \ :<C-u>call gita#action#exec('help', { 'name': 'commit_mapping' })<CR>

  noremap <silent><buffer> <Plug>(gita-action-update)
        \ :<C-u>call gita#action#exec('update')<CR>

  noremap <silent><buffer> <Plug>(gita-action-switch)
        \ :<C-u>call gita#action#exec('open_status')<CR>
  noremap <silent><buffer> <Plug>(gita-action-commit)
        \ :<C-u>call gita#action#exec('commit')<CR>

  " Define extra actual key mappings
  if enable_default_mappings
    nmap <buffer> <C-l> <Plug>(gita-action-update)

    nmap <buffer> cc <Plug>(gita-action-switch)
    nmap <buffer> CC <Plug>(gita-action-commit)
  endif
  call gita#features#commit#update({}, { 'force_update': 1 })
  silent execute printf("setlocal filetype=%s", s:const.filetype)
endfunction " }}}
function! gita#features#commit#update(...) abort " {{{
  let options = extend(
        \ deepcopy(w:_gita_options),
        \ get(a:000, 0, {}),
        \)
  let options.porcelain = 1
  let options.dry_run = 1
  let options.no_status = 1
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
  let statuses = s:S.parse(result.stdout)
  let gita = gita#get()

  " create statuses lines & map
  let statuses_map = {}
  let statuses_lines = []
  for status in statuses.all
    let record = printf('# %s', status.record)
    call add(statuses_lines, record)
    let statuses_map[record] = status
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
        \ ['# Press ?m and/or ?s to toggle a help of mapping and/or short format.'],
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
function! gita#features#commit#command(bang, range, ...) abort " {{{
  let options = s:parser.parse(a:bang, a:range, get(a:000, 0, ''))
  if !empty(options)
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


let &cpo = s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
