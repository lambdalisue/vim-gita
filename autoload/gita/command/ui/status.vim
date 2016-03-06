let s:V = gita#vital()
let s:Dict = s:V.import('Data.Dict')
let s:Path = s:V.import('System.Filepath')
let s:Anchor = s:V.import('Vim.Buffer.Anchor')
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

function! gita#command#ui#status#BufReadCmd(options) abort
  let options = gita#option#cascade('^status$', a:options, {
        \ 'encoding': '',
        \ 'fileformat': '',
        \ 'bad': '',
        \})
  let options['porcelain'] = 1
  let options['quiet'] = 1
  let result = gita#command#status#call(options)
  let statuses = gita#command#ui#status#parse_statuses(git, result.content)
  call gita#meta#set('content_type', 'status')
  call gita#meta#set('options', s:Dict.omit(result.options, [
        \ 'force', 'opener', 'porcelain',
        \]))
  call gita#meta#set('statuses', statuses)
  call gita#meta#set('filename', len(result.filenames) == 1 ? result.filenames[0] : '')
  call gita#meta#set('filenames', result.filenames)
  call gita#meta#set('winwidth', winwidth(0))
  call s:define_actions()
  call s:Anchor.register()
  " the following options are required so overwrite everytime
  setlocal filetype=gita-status
  setlocal buftype=nofile nobuflisted
  setlocal nomodifiable
  call gita#command#ui#status#redraw(options)
endfunction

function! gita#command#ui#status#bufname(...) abort
  let options = extend({
        \ 'filenames': [],
        \}, get(a:000, 0, {}))
  let git = gita#core#get_or_fail()
  return gita#autocmd#bufname(git, {
        \ 'filebase': 0,
        \ 'content_type': 'status',
        \ 'extra_options': [
        \   empty(options.filenames) ? '' : 'partial',
        \ ],
        \ 'commitish': '',
        \ 'path': '',
        \})
endfunction

function! gita#command#ui#status#open(...) abort
  let options = extend({
        \ 'anchor': 0,
        \ 'opener': '',
        \ 'selection': [],
        \}, get(a:000, 0, {}))
  let bufname = gita#command#ui#status#bufname(options)
  if empty(bufname)
    return
  endif
  let opener = empty(options.opener)
        \ ? g:gita#command#ui#status#default_opener
        \ : options.opener
  if options.anchor && s:Anchor.is_available(opener)
    call s:Anchor.focus()
  endif
  try
    let g:gita#var = options
    call gita#util#buffer#open(bufname, {
          \ 'opener': opener,
          \ 'window': 'manipulation_panel',
          \})
  finally
    silent! unlet! g:gita#var
  endtry
  call gita#util#select(options.selection)
endfunction

function! gita#command#ui#status#redraw(...) abort
  let git = gita#core#get_or_fail()
  let options = gita#option#cascade('^status$', get(a:000, 0, {}), {
        \ 'encoding': '',
        \ 'fileformat': '',
        \ 'bad': '',
        \})
  let prologue = [s:get_header_string(git)]
  let contents = s:format_statuses(gita#meta#get_for('status', 'statuses', []))
  let s:candidate_offset = len(prologue)
  call gita#util#buffer#edit_content(extend(prologue, contents), {
        \ 'encoding': options.encoding,
        \ 'fileformat': options.fileformat,
        \ 'bad': options.bad,
        \})
endfunction

function! gita#command#ui#status#parse_statuses(git, content) abort
  let statuses = s:GitParser.parse_status(a:content, {
        \ 'fail_silently': 0,
        \ 'flatten': 1,
        \})
  call map(statuses, 's:extend_status(a:git, v:val)')
  return sort(statuses, function('s:compare_statuses'))
endfunction

function! gita#command#ui#status#define_highlights() abort
  highlight default link GitaComment    Comment
  highlight default link GitaConflicted Error
  highlight default link GitaUnstaged   Constant
  highlight default link GitaStaged     Special
  highlight default link GitaUntracked  GitaUnstaged
  highlight default link GitaIgnored    Identifier
  highlight default link GitaBranch     Title
  highlight default link GitaHighlight  Keyword
  highlight default link GitaImportant  Constant
endfunction

function! gita#command#ui#status#define_syntax() abort
  syntax match GitaStaged     /^[ MADRC][ MD]/he=e-1 contains=ALL
  syntax match GitaUnstaged   /^[ MADRC][ MD]/hs=s+1 contains=ALL
  syntax match GitaStaged     /^[ MADRC]\s.*$/hs=s+3 contains=ALL
  syntax match GitaUnstaged   /^.[MDAU?].*$/hs=s+3 contains=ALL
  syntax match GitaIgnored    /^!!\s.*$/
  syntax match GitaUntracked  /^??\s.*$/
  syntax match GitaConflicted /^\%(DD\|AU\|UD\|UA\|DU\|AA\|UU\)\s.*$/
  syntax match GitaComment    /^.*$/ contains=ALL
  syntax match GitaBranch     /Gita status of [^ ]\+/hs=s+15 contained
  syntax match GitaBranch     /Gita status of [^ ]\+ <> [^ ]\+/hs=s+15 contained
  syntax match GitaHighlight  /\d\+ commit(s) ahead/ contained
  syntax match GitaHighlight  /\d\+ commit(s) behind/ contained
  syntax match GitaImportant  /REBASE-[mi] \d\/\d/
  syntax match GitaImportant  /REBASE \d\/\d/
  syntax match GitaImportant  /AM \d\/\d/
  syntax match GitaImportant  /AM\/REBASE \d\/\d/
  syntax match GitaImportant  /\%(MERGING\|CHERRY-PICKING\|REVERTING\|BISECTING\)/
endfunction

call gita#util#define_variables('command#ui#status', {
      \ 'default_opener': 'botright 10 split',
      \ 'default_action_mapping': '<Plug>(gita-edit)',
      \ 'disable_default_mappings': 0,
      \})
