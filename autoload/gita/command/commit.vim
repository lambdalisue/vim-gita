let s:V = gita#vital()
let s:List = s:V.import('Data.List')
let s:Dict = s:V.import('Data.Dict')
let s:Path = s:V.import('System.Filepath')
let s:Prompt = s:V.import('Vim.Prompt')
let s:Anchor = s:V.import('Vim.Buffer.Anchor')
let s:Guard = s:V.import('Vim.Guard')
let s:Git = s:V.import('Git')
let s:GitInfo = s:V.import('Git.Info')
let s:GitParser = s:V.import('Git.Parser')
let s:GitProcess = s:V.import('Git.Process')
let s:ArgumentParser = s:V.import('ArgumentParser')
let s:entry_offset = 0

function! s:pick_available_options(options) abort
  " Note:
  " Let me know or send me a PR if you need options not listed below
  let options = s:Dict.pick(a:options, [
        \ 'file',
        \ 'porcelain',
        \ 'dry-run',
        \ 'u', 'untracked-files',
        \ 'a', 'all',
        \ 'reset-author',
        \ 'allow-empty',
        \ 'amend',
        \])
  if s:GitInfo.get_git_version() =~# '^-\|^1\.[1-3]\.'
    " remove -u/--untracked-files which requires Git >= 1.4
    let options = s:Dict.omit(options, ['u', 'untracked-files'])
  endif
  return options
endfunction
function! s:get_commit_content(git, filenames, options) abort
  let options = s:pick_available_options(a:options)
  if !empty(a:filenames)
    let options['--'] = a:filenames
  endif
  let result = gita#execute(a:git, 'commit', options)
  if get(options, 'dry-run') && result.status == 1
    " Note:
    " Somehow 'git commit' return 1 when --dry-run is specified
    retur result.content
  elseif result.status
    call s:GitProcess.throw(result.stdout)
  endif
  return result.content
endfunction
function! s:get_current_commitmsg() abort
  return filter(getline(1, '$'), 'v:val !~# "^#"')
endfunction
function! s:save_commitmsg() abort
  call gita#set_meta('commitmsg_saved', s:get_current_commitmsg())
endfunction
function! s:commit_commitmsg() abort
  let git = gita#get_or_fail()
  let options = gita#get_meta('options')
  let statuses = gita#get_meta('statuses')
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
  if join(commitmsg) =~# '^\s*$'
    call gita#throw(
          \ 'Warning:',
          \ 'No commit message is written. Write a commit message first',
          \)
  endif

  let tempfile = tempname()
  try
    call writefile(commitmsg, tempfile)
    let options2 = deepcopy(options)
    let options2['file'] = tempfile
    let content = s:get_commit_content(git, [], options2)
    call s:Prompt.title(printf(
          \ 'OK: the changes on %d files have committed',
          \ len(staged_statuses),
          \))
    call s:Prompt.echo('None', join(content, "\n"))
    call gita#remove_meta('commitmsg_saved', '')
    call gita#set_meta('options', {})
    silent keepjumps %delete _
    call gita#util#doautocmd('User', 'GitaStatusModified')
  finally
    call delete(tempfile)
  endtry
endfunction

function! s:format_entry(entry) abort
  return '# ' . a:entry.record
endfunction

function! s:get_entry(index) abort
  let offset = 0
  for line in getline(1, '$')
    if line =~# '^#'
      break
    endif
    let offset += 1
  endfor
  let index = a:index - s:entry_offset - offset
  let statuses = gita#get_meta('statuses', [])
  return index >= 0 ? get(statuses, index, {}) : {}
endfunction
function! s:define_actions() abort
  let action = gita#action#define(function('s:get_entry'))
  function! action.actions.redraw(candidates, ...) abort
    call gita#command#commit#edit()
  endfunction
  function! action.actions.redraw(candidates, ...) abort
    call gita#command#commit#edit()
  endfunction
  function! action.actions.commit_do(candidates, ...) abort
    call s:commit_commitmsg()
    call gita#action#call('status')
  endfunction

  nnoremap <buffer><silent> <Plug>(gita-commit-do)
        \ :<C-u>call gita#action#call('commit_do')<CR>

  call gita#action#includes(
        \ g:gita#command#commit#enable_default_mappings, [
        \   'close', 'redraw', 'mapping',
        \   'edit', 'show', 'diff', 'blame', 'browse',
        \   'status',
        \])

  if g:gita#command#commit#enable_default_mappings
    execute printf(
          \ 'map <buffer> <Return> %s',
          \ g:gita#command#commit#default_action_mapping
          \)
    map <buffer> <C-c><C-c> <Plug>(gita-commit-do)
  endif
endfunction

function! s:on_BufReadCmd() abort
  try
    call gita#command#commit#edit()
  catch /^\%(vital: Git[:.]\|vim-gita:\)/
    call gita#util#handle_exception()
  endtry
endfunction
function! s:on_BufWriteCmd() abort
  try
    call s:save_commitmsg()
    setlocal nomodified
  catch /^\%(vital: Git[:.]\|vim-gita:\)/
    call gita#util#handle_exception()
  endtry
endfunction
function! s:on_VimResized() abort
  try
    call gita#command#commit#redraw()
  catch /^\%(vital: Git[:.]\|vim-gita:\)/
    call gita#util#handle_exception()
  endtry
endfunction
function! s:on_WinEnter() abort
  try
    if gita#get_meta('winwidth', winwidth(0)) != winwidth(0)
      call gita#command#commit#redraw()
    endif
  catch /^\%(vital: Git[:.]\|vim-gita:\)/
    call gita#util#handle_exception()
  endtry
endfunction
function! s:on_WinLeave() abort
  if exists('w:_vim_gita_commit_QuitPre')
    unlet w:_vim_gita_commit_QuitPre
    try
      if !&modified && s:Prompt.confirm('Do you want to commit changes?', 'y')
        call s:commit_commitmsg()
      endif
    catch /^\%(vital: Git[:.]\|vim-gita:\)/
      call gita#util#handle_exception()
    endtry
  endif
endfunction
function! s:on_QuitPre() abort
  let w:_vim_gita_commit_QuitPre = 1
endfunction
function! s:on_GitaStatusModified() abort
  try
    let winnum = winnr()
    keepjump windo
          \ if &filetype ==# 'gita-commit' |
          \   call gita#command#commit#edit() |
          \ endif
    execute printf('keepjump %dwincmd w', winnum)
  catch /^\%(vital: Git[:.]\|vim-gita:\)/
    call gita#util#handle_exception()
  endtry
endfunction

function! gita#command#commit#bufname(...) abort
  let options = gita#option#init('^commit$', get(a:000, 0, {}), {
        \ 'allow-empty': 0,
        \ 'filenames': [],
        \})
  let git = gita#get_or_fail()
  return gita#autocmd#bufname(git, {
        \ 'filebase': 0,
        \ 'content_type': 'commit',
        \ 'extra_options': [
        \   empty(options['allow-empty']) ? '' : 'allow-empty',
        \   empty(options.filenames) ? '' : 'partial',
        \ ],
        \ 'commitish': '',
        \ 'path': '',
        \})
endfunction
function! gita#command#commit#call(...) abort
  let options = gita#option#init('^commit$', get(a:000, 0, {}), {
        \ 'filenames': [],
        \ 'amend': 0,
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
  let content = s:get_commit_content(git, filenames, options)
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
function! gita#command#commit#open(...) abort
  let options = extend({
        \ 'opener': '',
        \}, get(a:000, 0, {}))
  let git = gita#get_or_fail()
  let opener = empty(options.opener)
        \ ? g:gita#command#commit#default_opener
        \ : options.opener
  let bufname = gita#command#commit#bufname(options)
  let guard = s:Guard.store('&eventignore')
  try
    set eventignore+=BufReadCmd
    call gita#util#buffer#open(bufname, {
          \ 'opener': opener,
          \ 'group': 'manipulation_panel',
          \})
  finally
    call guard.restore()
  endtry
  " cascade git instance of previous buffer which open this buffer
  let b:_git = git
  call gita#command#commit#edit(options)
endfunction
function! gita#command#commit#edit(...) abort
  let options = get(a:000, 0, {})
  let options['porcelain'] = 1
  let options['dry-run'] = 1
  let result = gita#command#commit#call(options)
  call gita#set_meta('content_type', 'commit')
  call gita#set_meta('options', s:Dict.omit(options, [
        \ 'force', 'opener', 'porcelain', 'dry-run',
        \]))
  call gita#set_meta('statuses', result.statuses)
  call gita#set_meta('filename', len(result.filenames) == 1 ? result.filenames[0] : '')
  call gita#set_meta('filenames', result.filenames)
  call gita#set_meta('winwidth', winwidth(0))
  call s:define_actions()
  augroup vim_gita_internal_commit
    autocmd! * <buffer>
    autocmd BufReadCmd  <buffer> nested call s:on_BufReadCmd()
    autocmd BufWriteCmd <buffer> call s:on_BufWriteCmd()
    autocmd VimResized  <buffer> call s:on_VimResized()
    autocmd WinEnter    <buffer> call s:on_WinEnter()
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
  call gita#command#commit#redraw()
  " NOTE:
  " Force filetype to gita-commit. Without the line below, somehow filetype
  " re-assigned to 'conf'.
  setlocal filetype=gita-commit
endfunction
function! gita#command#commit#redraw() abort
  if &filetype !=# 'gita-commit'
    call gita#throw('redraw() requires to be called in a gita-commit buffer')
  endif
  let git = gita#get_or_fail()
  let options = gita#get_meta('options')

  let commit_mode = ''
  if !empty(gita#get_meta('commitmsg_cached'))
    let commitmsg = gita#get_meta('commitmsg_cached')
    call gita#get_meta('commitmsg_cached', [])
    setlocal modified
  elseif !empty(gita#get_meta('commitmsg_saved'))
    let commitmsg = gita#get_meta('commitmsg_saved')
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
        \ ['# ' . gita#command#status#_get_header_string()],
        \ gita#action#mapping#get_visibility()
        \   ? map(gita#action#get_mapping_help(), '"# | " . v:val')
        \   : [],
        \ commit_mode ==# 'merge' ? ['# This branch is in MERGE mode.'] : [],
        \ commit_mode ==# 'amend' ? ['# This branch is in AMEND mode.'] : [],
        \])
  let statuses = gita#get_meta('statuses', [])
  let contents = map(
        \ copy(statuses),
        \ 's:format_entry(v:val)'
        \)
  let s:entry_offset = len(prologue)
  call gita#util#buffer#edit_content(
        \ commitmsg + prologue + contents
        \)
endfunction

function! s:get_parser() abort
  if !exists('s:parser') || g:gita#develop
    let s:parser = s:ArgumentParser.new({
          \ 'name': 'Gita commit',
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
    call s:parser.add_argument(
          \ '--amend',
          \ 'Amend',
          \)
    call s:parser.add_argument(
          \ '--allow-empty',
          \ 'Allow an empty commit',
          \)
    call s:parser.add_argument(
          \ '--reset-author',
          \ 'Allow an empty commit',
          \)
    call s:parser.add_argument(
          \ '--all', '-a',
          \ 'Allow an empty commit',
          \)
    call s:parser.add_argument(
          \ '--untracked-files', '-u',
          \ 'Allow an empty commit',
          \)
    " TODO: Add more arguments
  endif
  return s:parser
endfunction
function! gita#command#commit#command(...) abort
  let parser  = s:get_parser()
  let options = call(parser.parse, a:000, parser)
  if empty(options)
    return
  endif
  " extend default options
  let options = extend(
        \ deepcopy(g:gita#command#commit#default_options),
        \ options,
        \)
  call gita#command#commit#open(options)
endfunction
function! gita#command#commit#complete(...) abort
  let parser = s:get_parser()
  return call(parser.complete, a:000, parser)
endfunction
function! gita#command#commit#define_highlights() abort
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
function! gita#command#commit#define_syntax() abort
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

augroup vim_gita_internal_commit_update
  autocmd!
  autocmd User GitaStatusModified call s:on_GitaStatusModified()
augroup END

call gita#util#define_variables('command#commit', {
      \ 'default_options': { 'untracked-files': 1 },
      \ 'default_opener': 'botright 10 split',
      \ 'default_action_mapping': '<Plug>(gita-diff)',
      \ 'enable_default_mappings': 1,
      \})
