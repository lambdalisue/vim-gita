let s:V = gita#vital()
let s:List = s:V.import('Data.List')
let s:Dict = s:V.import('Data.Dict')
let s:Prompt = s:V.import('Vim.Prompt')
let s:Git = s:V.import('Git')
let s:GitInfo = s:V.import('Git.Info')
let s:GitParser = s:V.import('Git.Parser')

function! s:build_bufname(options) abort
  let options = extend({
        \ 'amend': 0,
        \}, a:options)
  return gita#content#build_bufname('commit', {
        \ 'nofile': 1,
        \ 'extra_options': [
        \   options.amend ? 'amend' : '',
        \ ],
        \})
endfunction

function! s:execute_command(options) abort
  let args = gita#util#args_from_options(a:options, {
        \ 'untracked-files': 1,
        \})
  let args = [
        \ 'commit',
        \ '--porcelain',
        \ '--dry-run',
        \] + args
  let args += ['--'] + get(a:options, 'filenames', [])
  return gita#command#execute(args, {
        \ 'quiet': 1,
        \ 'success_status': 1,
        \})
endfunction

function! s:execute_commit_command(options) abort
  let args = gita#util#args_from_options(a:options, {
        \ 'all': 1,
        \ 'reset-author': 1,
        \ 'file': 1,
        \ 'author': 1,
        \ 'date': 1,
        \ 'message': 1,
        \ 'allow-empty': 1,
        \ 'allow-empty-message': 1,
        \ 'amend': 1,
        \ 'untracked-files': 1,
        \ 'dry-run': 1,
        \ 'gpg-sign': 1,
        \ 'no-gpg-sign': 1,
        \})
  let args = ['commit', '--verbose'] + args
  let args += ['--'] + get(a:options, 'filenames', [])
  return gita#command#execute(args)
endfunction

function! s:define_actions() abort
  call gita#action#attach(function('s:get_candidate'))
  call gita#action#include([
        \ 'common', 'blame', 'browse',
        \ 'status', 'diff', 'edit', 'show', 'commit',
        \], g:gita#content#commit#disable_default_mappings)
  call gita#action#define('commit:do', function('s:action_commit_do'), {
        \ 'description': 'Commit changes',
        \ 'mapping_mode': 'n',
        \ 'options': {},
        \})

  if g:gita#content#commit#disable_default_mappings
    return
  endif
  execute printf(
        \ 'nmap <buffer> <Return> %s',
        \ g:gita#content#commit#primary_action_mapping
        \)
  execute printf(
        \ 'nmap <buffer> <S-Return> %s',
        \ g:gita#content#commit#secondary_action_mapping
        \)
  nmap <buffer> <C-c><C-c> <Plug>(gita-commit-do)
  nmap <buffer> <C-c><C-n> <Plug>(gita-commit-new)
  nmap <buffer> <C-c><C-a> <Plug>(gita-commit-amend)
  nmap <buffer> <C-^> <Plug>(gita-status)
endfunction

function! s:get_candidate(index) abort
  let record = matchstr(getline(a:index + 1), '^# \zs.*$')
  let statuses = gita#meta#get_for('^commit$', 'statuses', [])
  return gita#action#find_candidate(statuses, record, 'record')
endfunction

function! s:compare_statuses(lhs, rhs) abort
  if a:lhs.path ==# a:rhs.path
    return 0
  elseif a:lhs.path > a:rhs.path
    return 1
  else
    return -1
  endif
endfunction

function! s:get_prologue(git) abort
  let git = gita#core#get_or_fail()
  let local = s:GitInfo.get_local_branch(a:git)
  let remote = s:GitInfo.get_remote_branch(a:git)
  let mode = s:GitInfo.get_current_mode(a:git)
  let is_connected = !empty(remote.remote)

  let name = a:git.repository_name
  let branchinfo = is_connected
        \ ? printf('%s/%s <> %s/%s', name, local.name, remote.remote, remote.name)
        \ : printf('%s/%s', name, local.name)
  let connection = ''
  if is_connected
    let outgoing = s:GitInfo.count_commits_ahead_of_remote(a:git)
    let incoming = s:GitInfo.count_commits_behind_remote(a:git)
    if outgoing > 0 && incoming > 0
      let connection = printf(
            \ '%d commit(s) ahead and %d commit(s) behind of remote',
            \ outgoing, incoming,
            \)
    elseif outgoing > 0
      let connection = printf('%d commit(s) ahead remote', outgoing)
    elseif incoming > 0
      let connection = printf('%d commit(s) behind of remote', incoming)
    endif
  endif
  return printf('# Gita commit of %s%s%s %s',
        \ branchinfo,
        \ empty(connection) ? '' : printf(' (%s)', connection),
        \ empty(mode) ? '' : printf(' [%s]', mode),
        \ '| Press ? or <Tab> to show help or do action',
        \)
endfunction

function! s:get_current_commitmsg() abort
  return filter(getline(1, '$'), 'v:val !~# "^#"')
endfunction

function! s:save_commitmsg() abort
  call gita#meta#set('commitmsg_saved', s:get_current_commitmsg())
endfunction

function! s:commit_commitmsg() abort
  let git = gita#core#get_or_fail()
  let options = gita#meta#get_for('commit', 'options')
  let statuses = gita#meta#get_for('commit', 'statuses')
  let staged_statuses = filter(copy(statuses), 'v:val.is_staged')
  if !s:GitInfo.is_merging(git) && empty(staged_statuses) && !get(options, 'allow-empty')
    call gita#throw(
          \ 'An empty commit is not allowed. Add --allow-empty option to allow.',
          \)
  elseif &modified
    call gita#throw(
          \ 'Warning:',
          \ 'You have unsaved changes. Save the changes by ":w" first',
          \)
  endif

  let commitmsg = s:get_current_commitmsg()
  if join(commitmsg) =~# '^\s*$' && !get(options, 'allow-empty-message')
    call gita#throw(
          \ 'An empty commit message is not allowed. Add --allow-empty-message option to allow.',
          \)
  endif

  let tempfile = tempname()
  try
    call writefile(commitmsg, tempfile)
    call s:execute_commit_command(extend(copy(options), {
          \ 'file': tempfile,
          \}))
    call gita#meta#remove('commitmsg_saved', '')
    call gita#meta#set('options', {})
    silent keepjumps %delete _
    setlocal nomodified
    call gita#util#doautocmd('User', 'GitaStatusModified')
  finally
    call delete(tempfile)
  endtry
endfunction

function! s:commit_commitmsg_confirm() abort
  if !&modified && s:Prompt.confirm('Do you want to commit changes?', 'y')
    call s:commit_commitmsg()
  endif
endfunction

function! s:action_commit_do(candidate, options) abort
  call s:commit_commitmsg()
  call gita#action#call('status')
endfunction

function! s:on_BufReadCmd(options) abort
  call gita#util#doautocmd('BufReadPre')
  let options = gita#option#cascade('^status$', a:options, {
        \ 'untracked-files': 0,
        \})
  let content = filter(s:execute_command(options), '!empty(v:val)')
  let statuses = s:GitParser.parse_status(content, { 'flatten': 1 })
  let statuses = sort(statuses, function('s:compare_statuses'))
  call gita#meta#set('content_type', 'commit')
  call gita#meta#set('options', options)
  call gita#meta#set('statuses', statuses)
  call s:define_actions()
  augroup vim_gita_internal_commit
    autocmd! * <buffer>
    " NOTE:
    " During BufHidden or whatever, the current buffer will be moved onto
    " the next one so could not be used.
    autocmd WinLeave <buffer> nested call s:on_WinLeave()
    autocmd QuitPre  <buffer> call s:on_QuitPre()
  augroup END
  call gita#util#anchor#attach()
  call gita#util#observer#attach()
  " the following options are required so overwrite everytime
  setlocal filetype=gita-commit
  setlocal buftype=acwrite nobuflisted
  setlocal modifiable
  call gita#content#commit#redraw()
  call gita#util#doautocmd('BufReadPost')
endfunction

function! s:on_BufWriteCmd(options) abort
  call s:save_commitmsg()
  setlocal nomodified
endfunction

function! s:on_WinLeave() abort
  if exists('w:_vim_gita_commit_QuitPre')
    unlet w:_vim_gita_commit_QuitPre
    try
      call s:commit_commitmsg_confirm()
    catch /^\%(vital: Git[:.]\|vim-gita:\)/
      call gita#util#handle_exception()
    endtry
  endif
endfunction

function! s:on_QuitPre() abort
  let w:_vim_gita_commit_QuitPre = 1
endfunction

function! gita#content#commit#open(options) abort
  let options = extend({
        \ 'opener': '',
        \ 'window': 'manipulation_window',
        \}, a:options)
  let bufname = s:build_bufname(options)
  let opener = empty(options.opener)
        \ ? g:gita#content#commit#default_opener
        \ : options.opener
  call gita#util#cascade#set('commit', s:Dict.pick(options, [
        \ 'untracked-files',
        \ 'filenames',
        \]))
  call gita#util#buffer#open(bufname, {
        \ 'opener': opener,
        \ 'window': options.window,
        \})
endfunction

function! gita#content#commit#redraw() abort
  let git = gita#core#get_or_fail()
  let options = gita#meta#get_for('commit', 'options')

  let commit_mode = ''
  if !empty(gita#meta#get_for('commit', 'commitmsg_cached'))
    let commitmsg = gita#meta#get('commitmsg_cached')
    call gita#meta#get_for('commit', 'commitmsg_cached', [])
    setlocal modified
  elseif !empty(gita#meta#get_for('commit', 'commitmsg_saved'))
    let commitmsg = gita#meta#get_for('commit', 'commitmsg_saved')
  elseif s:GitInfo.is_merging(git)
    let commitmsg = s:GitInfo.get_merge_msg(git)
    let commit_mode = 'merge'
  elseif get(options, 'amend')
    let commitmsg = s:GitInfo.get_last_commitmsg(git)
    let commit_mode = 'amend'
  else
    let commitmsg = s:get_current_commitmsg()
  endif

  let prologue = s:List.flatten([
        \ [s:get_prologue(git)],
        \ commit_mode ==# 'merge' ? ['# This branch is in MERGE mode.'] : [],
        \ commit_mode ==# 'amend' ? ['# This branch is in AMEND mode.'] : [],
        \])
  let contents = map(
        \ copy(gita#meta#get_for('^commit$', 'statuses', [])),
        \ '''# '' . v:val.record',
        \)
  call gita#util#buffer#edit_content(
        \ commitmsg + extend(prologue, contents),
        \ gita#util#buffer#parse_cmdarg(),
        \)
endfunction

function! gita#content#commit#autocmd(name, bufinfo) abort
  let options = gita#util#cascade#get('status')
  for attribute in a:bufinfo.extra_options
    let options[attribute] = 1
  endfor
  call call('s:on_' . a:name, [options])
endfunction

call gita#util#define_variables('content#commit', {
      \ 'default_opener': 'botright 10 split',
      \ 'primary_action_mapping': '<Plug>(gita-show)',
      \ 'secondary_action_mapping': '<Plug>(gita-diff)',
      \ 'disable_default_mappings': 0,
      \})
