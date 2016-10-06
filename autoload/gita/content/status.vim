let s:V = gita#vital()
let s:BufferAnchor = s:V.import('Vim.Buffer.Anchor')
let s:GitParser = s:V.import('Git.Parser')

function! s:build_bufname(options) abort
  return gita#content#build_bufname('status', {
        \ 'nofile': 1,
        \ 'extra_options': [],
        \})
endfunction

function! s:args_from_options(git, options) abort
  let args = gita#process#args_from_options(a:options, {
        \ 'ignored': 1,
        \ 'ignore-submodules': 1,
        \ 'untracked-files': 1,
        \})
  let args = ['status', '--verbose'] + args
  return filter(args, '!empty(v:val)')
endfunction

function! s:execute_command(options) abort
  let git = gita#core#get_or_fail()
  let args = s:args_from_options(git, a:options)
  let args += [
        \ '--porcelain',
        \ '--no-column',
        \]
  let result = gita#process#execute(git, args, {
        \ 'quiet': 1,
        \ 'encode_output': 0,
        \})
  return filter(result.content, '!empty(v:val)')
endfunction

function! s:define_actions() abort
  call gita#action#attach(function('s:get_candidates'))
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
endfunction

function! s:get_candidates(startline, endline) abort
  let statuses = gita#meta#get_for('^status$', 'statuses', [])
  let records = getline(a:startline, a:endline)
  return gita#action#filter(statuses, records, 'record')
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
  let mode = gita#statusline#get_current_mode(a:git)
  let local = gita#statusline#get_local_branch(a:git)
  let remote = gita#statusline#get_remote_branch(a:git)
  let is_connected = !empty(remote.remote)

  let name = a:git.repository_name
  let branchinfo = is_connected
        \ ? printf('%s/%s <> %s/%s', name, local.name, remote.remote, remote.name)
        \ : printf('%s/%s', name, local.name)
  let connection = ''
  if is_connected
    let traffic = gita#statusline#get_traffic_count(a:git)
    if traffic.outgoing > 0 && traffic.incoming > 0
      let connection = printf(
            \ '%d commit(s) ahead and %d commit(s) behind of remote',
            \ traffic.outgoing, traffic.incoming,
            \)
    elseif traffic.outgoing > 0
      let connection = printf('%d commit(s) ahead remote', traffic.outgoing)
    elseif traffic.incoming > 0
      let connection = printf('%d commit(s) behind of remote', traffic.incoming)
    endif
  endif
  return printf('status of %s%s%s %s',
        \ branchinfo,
        \ empty(connection) ? '' : printf(' (%s)', connection),
        \ empty(mode) ? '' : printf(' [%s]', mode),
        \ '| Press ? to show help or <Tab> to select action',
        \)
endfunction

function! s:on_BufReadCmd(options) abort
  call gita#util#doautocmd('BufReadPre')
  let options = gita#util#option#cascade('^status$', a:options)
  let content = s:execute_command(options)
  let statuses = s:GitParser.parse_status(content, { 'flatten': 1 })
  let statuses = sort(statuses, function('s:compare_statuses'))
  call gita#meta#set('content_type', 'status')
  call gita#meta#set('options', options)
  call gita#meta#set('statuses', statuses)
  call s:define_actions()
  call s:BufferAnchor.attach()
  call gita#util#observer#attach()
  " the following options are required so overwrite everytime
  setlocal filetype=gita-status
  setlocal buftype=nofile nobuflisted
  setlocal bufhidden=wipe
  setlocal nomodifiable
  call gita#content#status#redraw()
  call gita#util#doautocmd('BufReadPost')
endfunction

function! gita#content#status#open(options) abort
  let options = extend({
        \ 'opener': 'botright 10 split',
        \ 'window': 'manipulation_window',
        \}, a:options)
  let bufname = s:build_bufname(options)
  call gita#util#cascade#set('status', options)
  call gita#util#buffer#open(bufname, {
        \ 'opener': options.opener,
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
  call call('s:on_' . a:name, [options])
endfunction

call gita#define_variables('content#status', {
      \ 'primary_action_mapping': '<Plug>(gita-edit)',
      \ 'disable_default_mappings': 0,
      \})
