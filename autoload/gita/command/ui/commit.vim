let s:V = gita#vital()
let s:List = s:V.import('Data.List')
let s:Dict = s:V.import('Data.Dict')
let s:Prompt = s:V.import('Vim.Prompt')
let s:Anchor = s:V.import('Vim.Buffer.Anchor')
let s:Close = s:V.import('Vim.Buffer.Close')
let s:GitInfo = s:V.import('Git.Info')
let s:candidate_offset = 0

function! s:get_candidate(index) abort
  let offset = 0
  for line in getline(1, '$')
    if line =~# '^#'
      break
    endif
    let offset += 1
  endfor
  let index = a:index - s:candidate_offset - offset
  let statuses = gita#meta#get_for('commit', 'statuses', [])
  return index >= 0 ? get(statuses, index, {}) : {}
endfunction

function! s:define_actions() abort
  call gita#action#attach(function('s:get_candidate'))
  call gita#action#include([
        \ 'common', 'edit', 'show', 'diff', 'browse', 'blame',
        \ 'status', 'commit',
        \], g:gita#command#ui#commit#disable_default_mappings)
  call gita#action#define('commit:do', function('s:action_commit_do'), {
        \ 'description': 'Commit changes',
        \ 'mapping_mode': 'n',
        \ 'options': {},
        \})
  if g:gita#command#ui#commit#disable_default_mappings
    return
  endif
  execute printf(
        \ 'nmap <buffer> <Return> %s',
        \ g:gita#command#ui#commit#default_action_mapping
        \)
  nmap <buffer> <C-c><C-c> <Plug>(gita-commit-do)
  nmap <buffer> <C-c><C-n> <Plug>(gita-commit-new)
  nmap <buffer> <C-c><C-a> <Plug>(gita-commit-amend)
  nmap <buffer> <C-^> <Plug>(gita-status)
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
  return printf('# Gita status of %s%s%s %s',
        \ branchinfo,
        \ empty(connection) ? '' : printf(' (%s)', connection),
        \ empty(mode) ? '' : printf(' [%s]', mode),
        \ '| Press ? to toggle a mapping help',
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
    call gita#command#commit#call(extend(copy(options), {
          \ 'quiet': 0,
          \ 'file': tempfile,
          \}))
    call gita#meta#remove('commitmsg_saved', '')
    call gita#meta#set('options', {})
    silent keepjumps %delete _
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
  let git = gita#core#get_or_fail()
  let options = gita#option#cascade('^commit$', a:options, {
        \ 'encoding': '',
        \ 'fileformat': '',
        \ 'bad': '',
        \})
  let options['porcelain'] = 1
  let options['dry-run'] = 1
  let options['quiet'] = 1
  let result = gita#command#commit#call(options)
  let statuses = gita#command#ui#status#parse_statuses(git, result.content)
  call gita#meta#set('content_type', 'commit')
  call gita#meta#set('options', s:Dict.omit(options, [
        \ 'force', 'opener', 'porcelain', 'dry-run',
        \]))
  call gita#meta#set('statuses', statuses)
  call gita#meta#set('filename', len(result.filenames) == 1 ? result.filenames[0] : '')
  call gita#meta#set('filenames', result.filenames)
  call gita#meta#set('winwidth', winwidth(0))
  call s:define_actions()
  augroup vim_gita_internal_commit
    autocmd! * <buffer>
    " NOTE:
    " During BufHidden or whatever, the current buffer will be moved onto
    " the next one so could not be used.
    autocmd WinLeave    <buffer> nested call s:on_WinLeave()
    autocmd QuitPre     <buffer> call s:on_QuitPre()
  augroup END
  " NOTE:
  " Vim.Buffer.Anchor.register use WinLeave thus it MUST called after autocmd
  " of this buffer has registered.
  call s:Anchor.register()
  " the following options are required so overwrite everytime
  setlocal filetype=gita-commit
  setlocal buftype=acwrite nobuflisted
  setlocal modifiable

  " Used for template system
  call gita#util#doautocmd('BufReadPre')
  setlocal filetype=gita-commit
  call gita#command#ui#commit#redraw(options)
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


function! gita#command#ui#commit#bufname(options) abort
  let options = extend({
        \ 'amend': 0,
        \ 'allow-empty': 0,
        \ 'filenames': [],
        \}, a:options)
  let git = gita#core#get_or_fail()
  return gita#autocmd#bufname({
        \ 'nofile': 1,
        \ 'content_type': 'commit',
        \ 'extra_option': [
        \   empty(options['amend']) ? '' : 'amend',
        \   empty(options['allow-empty']) ? '' : 'allow-empty',
        \ ],
        \})
endfunction

function! gita#command#ui#commit#open(...) abort
  let options = extend({
        \ 'anchor': 0,
        \ 'opener': '',
        \ 'selection': [],
        \}, get(a:000, 0, {}))
  let bufname = gita#command#ui#commit#bufname(options)
  if empty(bufname)
    return
  endif
  let opener = empty(options.opener)
        \ ? g:gita#command#ui#commit#default_opener
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

function! gita#command#ui#commit#redraw(...) abort
  let git = gita#core#get_or_fail()
  let options = gita#option#cascade('^commit$', get(a:000, 0, {}), {
        \ 'encoding': '',
        \ 'fileformat': '',
        \ 'bad': '',
        \})

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
        \ [s:get_header_string(git)],
        \ commit_mode ==# 'merge' ? ['# This branch is in MERGE mode.'] : [],
        \ commit_mode ==# 'amend' ? ['# This branch is in AMEND mode.'] : [],
        \])
  let statuses = gita#meta#get_for('commit', 'statuses', [])
  let contents = map(copy(statuses), '"# " . v:val.record')
  let s:candidate_offset = len(prologue)
  call gita#util#buffer#edit_content(commitmsg + prologue + contents, {
        \ 'encoding': options.encoding,
        \ 'fileformat': options.fileformat,
        \ 'bad': options.bad,
        \})
endfunction

function! gita#command#ui#commit#autocmd(name, options, attributes) abort
  let options = {}
  for option_name in split(a:attributes.extra_attribute, ':')
    let options[option_name] = 1
  endfor
  let options = extend(options, a:options)
  call call('s:on_' . a:name, [options])
endfunction

function! gita#command#ui#commit#define_highlights() abort
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

function! gita#command#ui#commit#define_syntax() abort
  syntax match GitaStaged     /^# [ MADRC][ MD]/hs=s+2,he=e-1 contains=ALL
  syntax match GitaUnstaged   /^# [ MADRC][ MD]/hs=s+3 contains=ALL
  syntax match GitaStaged     /^# [ MADRC]\s.*$/hs=s+5 contains=ALL
  syntax match GitaUnstaged   /^# .[MDAU?].*$/hs=s+5 contains=ALL
  syntax match GitaIgnored    /^# !!\s.*$/hs=s+2
  syntax match GitaUntracked  /^# ??\s.*$/hs=s+2
  syntax match GitaConflicted /^# \%(DD\|AU\|UD\|UA\|DU\|AA\|UU\)\s.*$/hs=s+2
  syntax match GitaComment    /^# .*$/ contains=ALL
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


call gita#util#define_variables('command#ui#commit', {
      \ 'default_opener': 'botright 10 split',
      \ 'default_action_mapping': '<Plug>(gita-diff)',
      \ 'disable_default_mappings': 0,
      \})
