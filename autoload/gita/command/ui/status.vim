let s:V = gita#vital()
let s:Dict = s:V.import('Data.Dict')
let s:Path = s:V.import('System.Filepath')
let s:Git = s:V.import('Git')
let s:GitInfo = s:V.import('Git.Info')
let s:GitParser = s:V.import('Git.Parser')
let s:candidate_offset = 0

function! s:get_candidate(index) abort
  let index = a:index - s:candidate_offset
  let statuses = gita#meta#get_for('status', 'statuses', [])
  return index >= 0 ? get(statuses, index, {}) : {}
endfunction

function! s:define_actions() abort
  call gita#action#attach(function('s:get_candidate'))
  call gita#action#include([
        \ 'common', 'index', 'blame', 'browse', 'checkout',
        \ 'commit', 'diff', 'discard', 'edit', 'patch',
        \ 'show',
        \], g:gita#command#ui#status#disable_default_mappings)

  if g:gita#command#ui#status#disable_default_mappings
    return
  endif
  execute printf(
        \ 'nmap <buffer> <Return> %s',
        \ g:gita#command#ui#status#default_action_mapping
        \)
  nmap <buffer> <C-^> <Plug>(gita-commit)
endfunction

function! s:extend_status(git, status) abort
  " NOTE:
  " git -C <rep> status --porcelain returns paths from the repository root
  " so convert it to a real absolute path
  let a:status.path = s:Git.get_absolute_path(
        \ a:git, s:Path.realpath(a:status.path),
        \)
  if has_key(a:status, 'path2')
    let a:status.path2 = s:Git.get_absolute_path(
          \ a:git, s:Path.realpath(a:status.path2),
          \)
  endif
  return a:status
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

function! s:format_status(status) abort
  return a:status.record
endfunction

function! s:format_statuses(statuses) abort
  let content = map(copy(a:statuses), 'v:val.record')
  return content
endfunction

function! s:get_header_string(git) abort
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
        \ '| Press ? to toggle a mapping help',
        \)
endfunction

function! s:get_bufname(...) abort
  let options = extend({
        \ 'filenames': [],
        \}, get(a:000, 0, {}))
  return gita#autocmd#bufname({
        \ 'nofile': 1,
        \ 'content_type': 'status',
        \ 'extra_option': [],
        \})
endfunction

function! s:on_BufReadCmd(options) abort
  let options = gita#option#cascade('^status$', a:options, {})
  let options['porcelain'] = 1
  let options['quiet'] = 1
  let result   = gita#command#status#call(options)
  let statuses = gita#command#ui#status#parse_statuses(result.content)
  call gita#meta#set('content_type', 'status')
  call gita#meta#set('options', s:Dict.omit(result.options, [
        \ 'opener', 'selection', 'quiet', 'porcelain',
        \]))
  call gita#meta#set('statuses', statuses)
  call gita#meta#set('filename', len(result.filenames) == 1 ? result.filenames[0] : '')
  call gita#meta#set('filenames', result.filenames)
  call gita#meta#set('winwidth', winwidth(0))
  call s:define_actions()
  call gita#util#anchor#attach()
  call gita#util#observer#attach()
  " the following options are required so overwrite everytime
  setlocal filetype=gita-status
  setlocal buftype=nofile nobuflisted
  setlocal nomodifiable
  call gita#command#ui#status#redraw()
endfunction


function! gita#command#ui#status#autocmd(name) abort
  let options = gita#util#cascade#get('status')
  call call('s:on_' . a:name, [options])
endfunction

function! gita#command#ui#status#open(...) abort
  let options = extend({
        \ 'anchor': 0,
        \ 'opener': '',
        \ 'selection': [],
        \}, get(a:000, 0, {}))
  let bufname = s:get_bufname(options)
  if empty(bufname)
    return
  endif
  let opener = empty(options.opener)
        \ ? g:gita#command#ui#status#default_opener
        \ : options.opener
  if options.anchor && gita#util#anchor#is_available(opener)
    call gita#util#anchor#focus()
  endif
  call gita#util#cascade#set('status', options)
  call gita#util#buffer#open(bufname, {
        \ 'opener': opener,
        \ 'window': 'manipulation_panel',
        \})
  call gita#util#select(options.selection)
endfunction

function! gita#command#ui#status#redraw() abort
  let git = gita#core#get_or_fail()
  let prologue = [s:get_header_string(git)]
  let s:candidate_offset = len(prologue)
  let contents = s:format_statuses(gita#meta#get_for('status', 'statuses', []))
  call gita#util#buffer#edit_content(
        \ extend(prologue, contents),
        \ gita#autocmd#parse_cmdarg(),
        \)
endfunction

function! gita#command#ui#status#parse_statuses(content) abort
  if len(a:content) == 1 && empty(a:content[0])
    return []
  endif
  let git = gita#core#get_or_fail()
  let statuses = s:GitParser.parse_status(a:content, {
        \ 'fail_silently': 0,
        \ 'flatten': 1,
        \})
  call map(statuses, 's:extend_status(git, v:val)')
  return sort(statuses, function('s:compare_statuses'))
endfunction


call gita#util#define_variables('command#ui#status', {
      \ 'default_opener': 'botright 10 split',
      \ 'default_action_mapping': '<Plug>(gita-edit)',
      \ 'disable_default_mappings': 0,
      \})
