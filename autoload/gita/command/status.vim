let s:V = gita#vital()
let s:List = s:V.import('Data.List')
let s:Dict = s:V.import('Data.Dict')
let s:Path = s:V.import('System.Filepath')
let s:Anchor = s:V.import('Vim.Buffer.Anchor')
let s:Guard = s:V.import('Vim.Guard')
let s:Git = s:V.import('Git')
let s:GitInfo = s:V.import('Git.Info')
let s:GitParser = s:V.import('Git.Parser')
let s:GitProcess = s:V.import('Git.Process')
let s:ArgumentParser = s:V.import('ArgumentParser')
let s:entry_offset = 0

function! s:pick_available_options(options) abort
  let options = s:Dict.pick(a:options, [
        \ 'untracked-files',
        \ 'ignore-submodules',
        \ 'ignored',
        \])
  if s:GitInfo.get_git_version() =~# '^-\|^1\.[1-3]\.'
    " remove -u/--untracked-files which requires Git >= 1.4
    let options = s:Dict.omit(options, ['u', 'untracked-files'])
  endif
  return options
endfunction
function! s:get_status_content(git, filenames, options) abort
  let options = s:pick_available_options(a:options)
  let options['porcelain'] = 1
  let options['no-column'] = 1
  if !empty(a:filenames)
    let options['--'] = a:filenames
  endif
  let result = gita#execute(a:git, 'status', options)
  if result.status
    call s:GitProcess.throw(result.stdout)
  endif
  return result.content
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
  let content = map(copy(a:statuses),
        \ 's:format_status(v:val)',
        \)
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

function! s:get_entry(index) abort
  let index = a:index - s:entry_offset
  let statuses = gita#get_meta('statuses', [])
  return index >= 0 ? get(statuses, index, {}) : {}
endfunction
function! s:define_actions() abort
  let action = gita#action#define(function('s:get_entry'))
  " Override 'redraw' action
  function! action.actions.redraw(candidates, ...) abort
    call gita#command#status#edit()
  endfunction

  call gita#action#includes(
        \ g:gita#command#status#enable_default_mappings, [
        \   'close', 'redraw', 'mapping',
        \   'add', 'rm', 'reset', 'checkout',
        \   'stage', 'unstage', 'toggle', 'discard',
        \   'edit', 'show', 'diff', 'blame', 'browse',
        \   'commit',
        \])

  if g:gita#command#status#enable_default_mappings
    execute printf(
          \ 'map <buffer> <Return> %s',
          \ g:gita#command#status#default_action_mapping
          \)
    nmap <buffer> <C-^> <Plug>(gita-commit)
  endif
endfunction

function! s:on_BufReadCmd() abort
  try
    call gita#command#status#edit()
  catch /^\%(vital: Git[:.]\|vim-gita:\)/
    call gita#util#handle_exception()
  endtry
endfunction
function! s:on_VimResized() abort
  try
    call gita#command#status#redraw()
  catch /^\%(vital: Git[:.]\|vim-gita:\)/
    call gita#util#handle_exception()
  endtry
endfunction
function! s:on_WinEnter() abort
  try
    if gita#get_meta('winwidth', winwidth(0)) != winwidth(0)
      call gita#command#status#redraw()
    endif
  catch /^\%(vital: Git[:.]\|vim-gita:\)/
    call gita#util#handle_exception()
  endtry
endfunction
function! s:on_GitaStatusModified() abort
  try
    let winnum = winnr()
    keepjump windo
          \ if &filetype ==# 'gita-status' |
          \   call gita#command#status#edit() |
          \ endif
    execute printf('keepjump %dwincmd w', winnum)
  catch /^\%(vital: Git[:.]\|vim-gita:\)/
    call gita#util#handle_exception()
  endtry
endfunction

function! gita#command#status#bufname(options) abort
  let options = extend({
        \ 'filenames': [],
        \}, a:options)
  let git = gita#get_or_fail()
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
function! gita#command#status#call(...) abort
  let options = gita#option#init('^status$', get(a:000, 0, {}), {
        \ 'filenames': [],
        \})
  let git = gita#get_or_fail()
  if !empty(options.filenames)
    let filenames = map(
          \ copy(options.filenames),
          \ 'gita#variable#get_valid_filename(v:val)',
          \)
  else
    let filenames = []
  endif
  let content = s:get_status_content(git, filenames, options)
  let result = {
        \ 'filenames': filenames,
        \ 'content': content,
        \ 'options': options,
        \}
  if get(options, 'porcelain')
    let result.statuses = gita#command#status#parse_statuses(git, content)
  endif
  return result
endfunction
function! gita#command#status#open(...) abort
  let options = extend({
        \ 'opener': '',
        \}, get(a:000, 0, {}))
  let git = gita#get_or_fail()
  let opener = empty(options.opener)
        \ ? g:gita#command#status#default_opener
        \ : options.opener
  let bufname = gita#command#status#bufname(options)
  let guard = s:Guard.store('&eventignore')
  try
    set eventignore+=BufReadCmd
    call gita#util#buffer#open(bufname, {
          \ 'opener': opener,
          \ 'window': 'manipulation_panel',
          \})
  finally
    call guard.restore()
  endtry
  " cascade git instance of previous buffer which open this buffer
  let b:_git = git
  call gita#command#status#edit(options)
endfunction
function! gita#command#status#edit(...) abort
  let options = gita#option#init('^status$', get(a:000, 0, {}))
  let options['porcelain'] = 1
  let result = gita#command#status#call(options)
  call gita#set_meta('content_type', 'status')
  call gita#set_meta('options', s:Dict.omit(result.options, [
        \ 'force', 'opener', 'porcelain',
        \]))
  call gita#set_meta('statuses', result.statuses)
  call gita#set_meta('filename', len(result.filenames) == 1 ? result.filenames[0] : '')
  call gita#set_meta('filenames', result.filenames)
  call gita#set_meta('winwidth', winwidth(0))
  call s:define_actions()
  call s:Anchor.register()
  augroup vim_gita_internal_status
    autocmd! * <buffer>
    autocmd BufReadCmd <buffer> nested call s:on_BufReadCmd()
    autocmd VimResized <buffer> call s:on_VimResized()
    autocmd WinEnter   <buffer> call s:on_WinEnter()
  augroup END
  " the following options are required so overwrite everytime
  setlocal filetype=gita-status
  setlocal buftype=nofile nobuflisted
  setlocal nomodifiable
  call gita#command#status#redraw()
endfunction
function! gita#command#status#redraw() abort
  if &filetype !=# 'gita-status'
    call gita#throw('redraw() requires to be called in a gita-status buffer')
  endif
  let git = gita#get_or_fail()
  let prologue = s:List.flatten([
        \ [s:get_header_string(git)],
        \ gita#action#mapping#get_visibility()
        \   ? map(gita#action#get_mapping_help(), '"| " . v:val')
        \   : []
        \])
  let statuses = gita#get_meta('statuses', [])
  let contents = s:format_statuses(statuses)
  let s:entry_offset = len(prologue)
  call gita#util#buffer#edit_content(extend(prologue, contents))
endfunction

function! s:get_parser() abort
  if !exists('s:parser') || g:gita#develop
    let s:parser = s:ArgumentParser.new({
          \ 'name': 'Gita status',
          \ 'description': 'Show a status of the repository',
          \ 'complete_unknown': function('gita#variable#complete_filename'),
          \ 'unknown_description': 'filenames',
          \ 'complete_threshold': g:gita#complete_threshold,
          \})
    call s:parser.add_argument(
          \ '--opener', '-o',
          \ 'A way to open a new buffer such as "edit", "split", etc.', {
          \   'type': s:ArgumentParser.types.value,
          \})
  endif
  return s:parser
endfunction
function! gita#command#status#command(...) abort
  let parser  = s:get_parser()
  let options = call(parser.parse, a:000, parser)
  if empty(options)
    return
  endif
  " extend default options
  let options = extend(
        \ deepcopy(g:gita#command#status#default_options),
        \ options,
        \)
  call gita#command#status#open(options)
endfunction
function! gita#command#status#complete(...) abort
  let parser = s:get_parser()
  return call(parser.complete, a:000, parser)
endfunction
function! gita#command#status#define_highlights() abort
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
function! gita#command#status#define_syntax() abort
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
function! gita#command#status#_get_header_string() abort
  let git = gita#get()
  if git.is_enabled
    return s:get_header_string(git)
  else
    return ''
  endif
endfunction
function! gita#command#status#parse_statuses(git, content) abort
  let statuses = s:GitParser.parse_status(a:content, {
        \ 'fail_silently': 1,
        \ 'flatten': 1,
        \})
  call map(statuses, 's:extend_status(a:git, v:val)')
  return sort(statuses, function('s:compare_statuses'))
endfunction

augroup vim_gita_internal_status_update
  autocmd!
  autocmd User GitaStatusModified call s:on_GitaStatusModified()
augroup END

call gita#util#define_variables('command#status', {
      \ 'default_options': { 'untracked-files': 1 },
      \ 'default_opener': 'botright 10 split',
      \ 'default_action_mapping': '<Plug>(gita-edit)',
      \ 'enable_default_mappings': 1,
      \})
