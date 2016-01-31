let s:V = hita#vital()
let s:List = s:V.import('Data.List')
let s:Dict = s:V.import('Data.Dict')
let s:Path = s:V.import('System.Filepath')
let s:Anchor = s:V.import('Vim.Buffer.Anchor')
let s:Git = s:V.import('Git')
let s:GitInfo = s:V.import('Git.Info')
let s:GitParser = s:V.import('Git.Parser')
let s:GitProcess = s:V.import('Git.Process')
let s:ArgumentParser = s:V.import('ArgumentParser')
let s:entry_offset = 0

function! s:pick_available_options(options) abort
  let options = s:Dict.pick(a:options, [
        \ 'porcelain',
        \ 'ignored',
        \ 'ignore-submodules',
        \ 'u', 'untracked-files',
        \])
  if s:GitInfo.get_git_version() =~# '^-\|^1\.[1-3]\.'
    " remove -u/--untracked-files which requires Git >= 1.4
    let options = s:Dict.omit(options, ['u', 'untracked-files'])
  endif
  return options
endfunction
function! s:get_status_content(git, filenames, options) abort
  let options = s:pick_available_options(a:options)
  if !empty(a:filenames)
    let options['--'] = a:filenames
  endif
  let result = hita#execute(a:git, 'status', options)
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
function! s:format_entry(entry) abort
  return a:entry.record
endfunction
function! s:get_statusline_string(git) abort
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
  return printf('Hita status of %s%s%s',
        \ branchinfo,
        \ empty(connection) ? '' : printf(' (%s)', connection),
        \ empty(mode) ? '' : printf(' [%s]', mode),
        \)
endfunction

function! s:get_entry(index) abort
  let index = a:index - s:entry_offset
  let statuses = hita#get_meta('statuses', [])
  return index >= 0 ? get(statuses, index, {}) : {}
endfunction
function! s:define_actions() abort
  let action = hita#action#define(function('s:get_entry'))
  " Override 'redraw' action
  function! action.actions.redraw(candidates, ...) abort
    call hita#command#status#update()
  endfunction

  call hita#action#includes(
        \ g:hita#command#status#enable_default_mappings, [
        \   'close', 'redraw', 'mapping',
        \   'add', 'rm', 'reset', 'checkout',
        \   'stage', 'unstage', 'toggle', 'discard',
        \   'edit', 'show', 'diff', 'blame', 'browse',
        \   'commit',
        \])

  if g:hita#command#status#enable_default_mappings
    execute printf(
          \ 'map <buffer> <Return> %s',
          \ g:hita#command#status#default_action_mapping
          \)
  endif
endfunction

function! s:on_BufReadCmd() abort
  try
    call hita#command#status#update()
  catch /^\%(vital: Git[:.]\|vim-hita:\)/
    call hita#util#handle_exception()
  endtry
endfunction
function! s:on_VimResized() abort
  try
    call hita#command#status#redraw()
  catch /^\%(vital: Git[:.]\|vim-hita:\)/
    call hita#util#handle_exception()
  endtry
endfunction
function! s:on_WinEnter() abort
  try
    if hita#get_meta('winwidth', winwidth(0)) != winwidth(0)
      call hita#command#status#redraw()
    endif
  catch /^\%(vital: Git[:.]\|vim-hita:\)/
    call hita#util#handle_exception()
  endtry
endfunction
function! s:on_HitaStatusModified() abort
  try
    let winnum = winnr()
    keepjump windo
          \ if &filetype ==# 'hita-status' |
          \   call hita#command#status#update() |
          \ endif
    execute printf('keepjump %dwincmd w', winnum)
  catch /^\%(vital: Git[:.]\|vim-hita:\)/
    call hita#util#handle_exception()
  endtry
endfunction

function! hita#command#status#bufname(...) abort
  let options = hita#option#init('^status$', get(a:000, 0, {}), {
        \ 'filenames': [],
        \})
  let git = hita#get_or_fail()
  return hita#autocmd#bufname(git, {
        \ 'filebase': 0,
        \ 'content_type': 'status',
        \ 'extra_options': [
        \   empty(options.filenames) ? '' : 'partial',
        \ ],
        \ 'commitish': '',
        \ 'path': '',
        \})
endfunction
function! hita#command#status#call(...) abort
  let options = hita#option#init('^status$', get(a:000, 0, {}), {
        \ 'filenames': [],
        \})
  let git = hita#get_or_fail()
  if !empty(options.filenames)
    let filenames = map(
          \ copy(options.filenames),
          \ 'hita#variable#get_valid_filename(v:val)',
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
    let result.statuses = hita#command#status#parse_statuses(git, content)
  endif
  return result
endfunction
function! hita#command#status#open(...) abort
  let options = extend({
        \ 'opener': '',
        \}, get(a:000, 0, {}))
  let git = hita#get_or_fail()
  let opener = empty(options.opener)
        \ ? g:hita#command#status#default_opener
        \ : options.opener
  let bufname = hita#command#status#bufname(options)
  call hita#util#buffer#open(bufname, {
        \ 'opener': opener,
        \ 'group': 'manipulation_panel',
        \})
  " cascade git instance of previous buffer which open this buffer
  let b:_git = git
  let options['porcelain'] = 1
  let result = hita#command#status#call(options)
  call hita#set_meta('content_type', 'status')
  call hita#set_meta('options', s:Dict.omit(result.options, [
        \ 'force', 'opener', 'porcelain',
        \]))
  call hita#set_meta('statuses', result.statuses)
  call hita#set_meta('filename', len(result.filenames) == 1 ? result.filenames[0] : '')
  call hita#set_meta('filenames', result.filenames)
  call hita#set_meta('winwidth', winwidth(0))
  call s:define_actions()
  call s:Anchor.register()
  augroup vim_hita_internal_status
    autocmd! * <buffer>
    autocmd BufReadCmd <buffer> call s:on_BufReadCmd()
    autocmd VimResized <buffer> call s:on_VimResized()
    autocmd WinEnter   <buffer> call s:on_WinEnter()
  augroup END
  " the following options are required so overwrite everytime
  setlocal filetype=hita-status
  setlocal buftype=nofile nobuflisted
  setlocal nomodifiable
  call hita#command#status#redraw()
endfunction
function! hita#command#status#update(...) abort
  if &filetype !=# 'hita-status'
    call hita#throw('update() requires to be called in a hita-status buffer')
  endif
  let options = get(a:000, 0, {})
  let options['porcelain'] = 1
  let result = hita#command#status#call(options)
  call hita#set_meta('content_type', 'status')
  call hita#set_meta('options', s:Dict.omit(result.options, [
        \ 'force', 'opener', 'porcelain',
        \]))
  call hita#set_meta('statuses', result.statuses)
  call hita#set_meta('filename', len(result.filenames) == 1 ? result.filenames[0] : '')
  call hita#set_meta('filenames', result.filenames)
  call hita#set_meta('winwidth', winwidth(0))
  call hita#command#status#redraw()
endfunction
function! hita#command#status#redraw() abort
  if &filetype !=# 'hita-status'
    call hita#throw('redraw() requires to be called in a hita-status buffer')
  endif
  let git = hita#get_or_fail()
  let prologue = s:List.flatten([
        \ g:hita#command#status#show_status_string_in_prologue
        \   ? [s:get_statusline_string(git) . ' | Press ? to toggle a mapping help']
        \   : [],
        \ hita#action#mapping#get_visibility()
        \   ? map(hita#action#get_mapping_help(), '"| " . v:val')
        \   : []
        \])
  let statuses = hita#get_meta('statuses', [])
  let contents = map(
        \ copy(statuses),
        \ 's:format_entry(v:val)'
        \)
  let s:entry_offset = len(prologue)
  call hita#util#buffer#edit_content(extend(prologue, contents))
endfunction

function! s:get_parser() abort
  if !exists('s:parser') || g:hita#develop
    let s:parser = s:ArgumentParser.new({
          \ 'name': 'Hita status',
          \ 'description': 'Show a status of the repository',
          \ 'complete_unknown': function('hita#variable#complete_filename'),
          \ 'unknown_description': 'filenames',
          \ 'complete_threshold': g:hita#complete_threshold,
          \})
    call s:parser.add_argument(
          \ '--opener', '-o',
          \ 'A way to open a new buffer such as "edit", "split", etc.', {
          \   'type': s:ArgumentParser.types.value,
          \})
    " TODO: Add more arguments
  endif
  return s:parser
endfunction
function! hita#command#status#command(...) abort
  let parser  = s:get_parser()
  let options = call(parser.parse, a:000, parser)
  if empty(options)
    return
  endif
  " extend default options
  let options = extend(
        \ deepcopy(g:hita#command#status#default_options),
        \ options,
        \)
  call hita#command#status#open(options)
endfunction
function! hita#command#status#complete(...) abort
  let parser = s:get_parser()
  return call(parser.complete, a:000, parser)
endfunction
function! hita#command#status#define_highlights() abort
  highlight default link HitaComment    Comment
  highlight default link HitaConflicted Error
  highlight default link HitaUnstaged   Constant
  highlight default link HitaStaged     Special
  highlight default link HitaUntracked  HitaUnstaged
  highlight default link HitaIgnored    Identifier
  highlight default link HitaBranch     Title
  highlight default link HitaHighlight  Keyword
  highlight default link HitaImportant  Constant
endfunction
function! hita#command#status#define_syntax() abort
  syntax match HitaStaged     /^[ MADRC][ MD]/he=e-1 contains=ALL
  syntax match HitaUnstaged   /^[ MADRC][ MD]/hs=s+1 contains=ALL
  syntax match HitaStaged     /^[ MADRC]\s.*$/hs=s+3 contains=ALL
  syntax match HitaUnstaged   /^.[MDAU?].*$/hs=s+3 contains=ALL
  syntax match HitaIgnored    /^!!\s.*$/
  syntax match HitaUntracked  /^??\s.*$/
  syntax match HitaConflicted /^\%(DD\|AU\|UD\|UA\|DU\|AA\|UU\)\s.*$/
  syntax match HitaComment    /^.*$/ contains=ALL
  syntax match HitaBranch     /Hita status of [^ ]\+/hs=s+15 contained
  syntax match HitaBranch     /Hita status of [^ ]\+ <> [^ ]\+/hs=s+15 contained
  syntax match HitaHighlight  /\d\+ commit(s) ahead/ contained
  syntax match HitaHighlight  /\d\+ commit(s) behind/ contained
  syntax match HitaImportant  /REBASE-[mi] \d\/\d/
  syntax match HitaImportant  /REBASE \d\/\d/
  syntax match HitaImportant  /AM \d\/\d/
  syntax match HitaImportant  /AM\/REBASE \d\/\d/
  syntax match HitaImportant  /\%(MERGING\|CHERRY-PICKING\|REVERTING\|BISECTING\)/
endfunction
function! hita#command#status#get_statusline_string() abort
  let git = hita#get()
  if git.is_enabled
    return s:get_statusline_string(git)
  else
    return ''
  endif
endfunction
function! hita#command#status#parse_statuses(git, content) abort
  let statuses = s:GitParser.parse_status(a:content, {
        \ 'fail_silently': 1,
        \ 'flatten': 1,
        \})
  call map(statuses, 's:extend_status(a:git, v:val)')
  return sort(statuses, function('s:compare_statuses'))
endfunction

augroup vim_hita_internal_status_update
  autocmd!
  autocmd User HitaStatusModified call s:on_HitaStatusModified()
augroup END

call hita#util#define_variables('command#status', {
      \ 'default_options': { 'untracked-files': 1 },
      \ 'default_opener': 'botright 10 split',
      \ 'default_action_mapping': '<Plug>(hita-edit)',
      \ 'enable_default_mappings': 1,
      \ 'show_status_string_in_prologue': 1,
      \})
