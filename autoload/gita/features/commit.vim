let s:save_cpo = &cpo
set cpo&vim


let s:L = gita#utils#import('Data.List')
let s:D = gita#utils#import('Data.Dict')
let s:F = gita#utils#import('System.File')
let s:S = gita#utils#import('VCS.Git.StatusParser')
let s:A = gita#utils#import('ArgumentParser')


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
function! s:smart_map(...) abort " {{{
  return call('gita#window#smart_map', a:000)
endfunction " }}}
function! s:get_current_commitmsg() abort " {{{
  return filter(getline(1, '$'), 'v:val !~# "^#"')
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


let s:parser = s:A.new({
      \ 'name': 'Gita commit',
      \ 'description': 'Record changes to the repository',
      \})
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


let s:actions = {}
function! s:actions.update(statuses, options) abort " {{{
  call gita#features#commit#update(a:options)
endfunction " }}}
function! s:actions.open_status(statuses, options) abort " {{{
  if &modified
    let w:_gita_options.commitmsg_cached = s:get_current_commitmsg()
    setlocal nomodified
  endif
  call gita#features#status#open(a:options)
endfunction " }}}
function! s:actions.commit(statuses, options) abort " {{{
  let gita = gita#core#get()
  let meta = gita.git.get_meta()
  " validate situation
  let staged_statuses = filter(values(w:_gita_statuses_map), 'v:val.is_staged')
  if empty(meta.merge_head) && empty(staged_statuses)
    " not in merge mode and nothing has been staged
    redraw
    call gita#utils#warn(
          \ 'No changes exist for commit. Stage changes first.',
          \)
    return
  elseif &modified
    redraw
    call gita#utils#warn(
          \ 'You have unsaved changes on the commit message.',
          \ 'Save the changes by ":w" command first.',
          \)
    return
  endif

  " validate commitmsg
  let commitmsg = s:get_current_commitmsg()
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
  let options = extend(a:options, w:_gita_options)
  let options.file = tempname()
  call writefile(commitmsg, options.file)
  let result = gita#features#commit#exec(options, {
        \ 'echo': 'both',
        \})
  if result.status == 0
    " force to refresh option in next launch
    let w:_gita_options = extend(w:_gita_options, {
          \ 'new': 1,
          \ 'amend': 0,
          \ 'commitmsg_cached': '',
          \ 'commitmsg_saved': '',
          \})
  endif
  if !get(w:_gita_options, 'quitting')
    call self.update(a:statuses, a:options)
  endif
endfunction " }}}


function! gita#features#commit#exec(...) abort " {{{
  let gita = gita#core#get()
  let options = get(a:000, 0, {})
  let config = get(a:000, 1, {})
  if !gita.enabled
    redraw
    call gita#utils#warn(
          \ 'Gita is not available in the current buffer.',
          \)
    return
  endif
  let options = s:D.pick(options, [
        \ '--',
        \ 'file',
        \ 'porcelain',
        \ 'dry_run', 'no_status',
        \ 'u', 'untracked_files',
        \ 'a', 'all',
        \ 'reset_author',
        \ 'ammend',
        \])
  return gita.operations.commit(options, config)
endfunction " }}}
function! gita#features#commit#open(...) abort " {{{
  let options = gita#window#extend_options(get(a:000, 0, {}))
  let config = get(a:000, 1, {})
  " Open the window and extend actions
  call gita#window#open('commit', options, config)
  call gita#window#extend_actions(s:actions)

  " Define options and extra AutoCmd
  setlocal buftype=acwrite bufhidden=hide
  augroup vim-gita-commit-window
    autocmd! * <buffer>
    autocmd BufWriteCmd <buffer> call s:ac_write(expand('<amatch>'))
  augroup END

  " Define hook functions
  function! b:_gita_hooks.pre_ac_quit(...) abort
    if expand('%') =~# '^gita\[:_\]commit$'
      call s:actions.commit({}, w:_gita_options)
    endif
  endfunction

  " Define extra Plug key mappings
  noremap <silent><buffer> <Plug>(gita-action-help-m)
        \ :<C-u>call gita#window#action('help', { 'name': 'commit_mapping' })<CR>
  noremap <silent><buffer> <Plug>(gita-action-update)
        \ :<C-u>call gita#window#action('update')<CR>
  noremap <silent><buffer> <Plug>(gita-action-switch)
        \ :<C-u>call gita#window#action('open_status')<CR>
  noremap <silent><buffer> <Plug>(gita-action-commit)
        \ :call gita#window#action('commit')<CR>

  " Define extra actual key mappings
  if get(g:, 'gita#features#commit#enable_default_mappings', 1)
    nmap <buffer> <C-l> <Plug>(gita-action-update)

    nmap <buffer> cc <Plug>(gita-action-switch)
    nmap <buffer> CC <Plug>(gita-action-commit)
  endif
  call gita#features#commit#update(options)
endfunction " }}}
function! gita#features#commit#update(...) abort " {{{
  let gita = gita#core#get()
  let options = extend(gita#window#extend_options(get(a:000, 0, {})), {
        \ 'porcelain': 1,
        \ 'dry_run': 1,
        \ 'no_status': 1,
        \})
  let result = gita#features#commit#exec(options, {
        \ 'echo': '',
        \ 'doautocmd': 0,
        \ 'success_status': 1,
        \})
  if result.status != 1
    bwipe
    return
  endif
  let statuses = s:S.parse(result.stdout)

  " create statuses lines & map
  let statuses_map = {}
  let statuses_lines = []
  for status in statuses.all
    let record = printf('# %s', status.record)
    call add(statuses_lines, record)
    let statuses_map[record] = status
  endfor
  let w:_gita_statuses_map = statuses_map

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
    call gita#features#commit#open(options)
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
