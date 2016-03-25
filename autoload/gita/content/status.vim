let s:V = gita#vital()
let s:Prelude = s:V.import('Prelude')
let s:Dict = s:V.import('Data.Dict')
let s:Git = s:V.import('Git')
let s:GitInfo = s:V.import('Git.Info')
let s:GitParser = s:V.import('Git.Parser')

function! s:build_bufname(options) abort
  let options = extend({
        \ 'ignored': 0,
        \}, a:options)
  return gita#content#build_bufname('status', {
        \ 'nofile': 1,
        \ 'extra_options': [
        \   options.ignored ? 'ignored' : '',
        \ ],
        \})
endfunction

function! s:execute_command(options) abort
  let args = gita#util#args_from_options(a:options, {
        \ 'untracked-files': 1,
        \ 'ignore-submodules': 1,
        \ 'ignored-submodules': 1,
        \})
  let args = [
        \ 'status',
        \ '--porcelain',
        \ '--no-column',
        \] + args
  let args += ['--'] + get(a:options, 'filenames', [])
  return gita#command#execute(args, { 'quiet': 1 })
endfunction

function! s:define_actions() abort
  call gita#action#attach(function('s:get_candidate'))
  call gita#action#include([
        \ 'common', 'index', 'blame', 'browse', 'checkout',
        \ 'commit', 'diff', 'discard', 'edit', 'patch', 'chaperone',
        \ 'show',
        \], g:gita#content#status#disable_default_mappings)

  if g:gita#content#status#disable_default_mappings
    return
  endif
  execute printf(
        \ 'nmap <buffer> <Return> %s',
        \ g:gita#content#status#primary_action_mapping
        \)
  nmap <buffer><nowait> <C-^> <Plug>(gita-commit)
endfunction

function! s:get_candidate(index) abort
  let record = getline(a:index + 1)
  let statuses = gita#meta#get_for('^status$', 'statuses', [])
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
  return printf('Gita status of %s%s%s %s',
        \ branchinfo,
        \ empty(connection) ? '' : printf(' (%s)', connection),
        \ empty(mode) ? '' : printf(' [%s]', mode),
        \ '| Press ? or <Tab> to show help or do action',
        \)
endfunction

function! s:on_BufReadCmd(options) abort
  call gita#util#doautocmd('BufReadPre')
  let options = gita#option#cascade('^status$', a:options, {
        \ 'untracked-files': 0,
        \ 'ignore-submodules': 0,
        \ 'ignored': 0,
        \})
  let content = filter(s:execute_command(options), '!empty(v:val)')
  let statuses = s:GitParser.parse_status(content, { 'flatten': 1 })
  let statuses = sort(statuses, function('s:compare_statuses'))
  call gita#meta#set('content_type', 'status')
  call gita#meta#set('options', options)
  call gita#meta#set('statuses', statuses)
  call s:define_actions()
  call gita#util#anchor#attach()
  call gita#util#observer#attach()
  " the following options are required so overwrite everytime
  setlocal filetype=gita-status
  setlocal buftype=nofile nobuflisted
  setlocal nomodifiable
  call gita#content#status#redraw()
  call gita#util#doautocmd('BufReadPost')
endfunction

function! gita#content#status#open(options) abort
  let options = extend({
        \ 'opener': '',
        \ 'window': 'manipulation_window',
        \}, a:options)
  let bufname = s:build_bufname(options)
  let opener = empty(options.opener)
        \ ? g:gita#content#status#default_opener
        \ : options.opener
  call gita#util#cascade#set('status', s:Dict.pick(options, [
        \ 'untracked-files',
        \ 'ignore-submodules',
        \ 'filenames',
        \]))
  call gita#util#buffer#open(bufname, {
        \ 'opener': opener,
        \ 'window': options.window,
        \})
endfunction

function! gita#content#status#redraw() abort
  let git = gita#core#get_or_fail()
  let prologue = [s:get_prologue(git)]
  let contents = map(
        \ copy(gita#meta#get_for('^status$', 'statuses', [])),
        \ 'v:val.record',
        \)
  call gita#util#buffer#edit_content(
        \ extend(prologue, contents),
        \ gita#util#buffer#parse_cmdarg(),
        \)
endfunction

function! gita#content#status#autocmd(name, bufinfo) abort
  let options = gita#util#cascade#get('status')
  for attribute in a:bufinfo.extra_options
    let options[attribute] = 1
  endfor
  call call('s:on_' . a:name, [options])
endfunction

call gita#util#define_variables('content#status', {
      \ 'default_opener': 'botright 10 split',
      \ 'primary_action_mapping': '<Plug>(gita-edit)',
      \ 'disable_default_mappings': 0,
      \})
