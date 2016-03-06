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
        \ 'all',
        \ 'reset-author',
        \ 'file',
        \ 'author',
        \ 'date',
        \ 'message',
        \ 'allow-empty',
        \ 'allow-empty-message',
        \ 'amend',
        \ 'untracked-files',
        \ 'dry-run',
        \ 'gpg-sign',
        \ 'no-gpg-sign',
        \ 'porcelain',
        \])
  if s:GitInfo.get_git_version() =~# '^-\|^1\.[1-3]\.'
    " remove -u/--untracked-files which requires Git >= 1.4
    let options = s:Dict.omit(options, ['u', 'untracked-files'])
  endif
  return options
endfunction
function! s:get_commit_content(git, filenames, options) abort
  let options = s:pick_available_options(a:options)
  let options['verbose'] = 1
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
  elseif !get(a:options, 'quiet', 0)
    call s:Prompt.title('OK: ' . join(result.args, ' '))
    echo join(result.content, "\n")
  endif
  return result.content
endfunction
function! s:get_current_commitmsg() abort
  return filter(getline(1, '$'), 'v:val !~# "^#"')
endfunction
function! s:save_commitmsg() abort
  call gita#meta#set('commitmsg_saved', s:get_current_commitmsg())
endfunction
function! s:commit_commitmsg() abort
  let git = gita#core#get_or_fail()
  let options = gita#meta#get('options')
  let statuses = gita#meta#get('statuses')
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
    let options2 = deepcopy(options)
    let options2['file'] = tempfile
    let content = s:get_commit_content(git, [], options2)
    call s:Prompt.title(printf(
          \ 'OK: the changes on %d files have committed',
          \ len(staged_statuses),
          \))
    call s:Prompt.echo('None', join(content, "\n"))
    call gita#meta#remove('commitmsg_saved', '')
    call gita#meta#set('options', {})
    silent keepjumps %delete _
    call gita#util#doautocmd('User', 'GitaStatusModified')
  finally
    call delete(tempfile)
  endtry
endfunction
  function! s:action_commit_do(candidates, options) abort
    call s:commit_commitmsg()
    call gita#action#call('status')
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
  let statuses = gita#meta#get('statuses', [])
  return index >= 0 ? get(statuses, index, {}) : {}
endfunction
function! s:define_actions() abort
  call gita#action#attach(function('s:get_entry'))
  call gita#action#include([
        \ 'common', 'edit', 'show', 'diff', 'browse', 'blame',
        \ 'status', 'commit',
        \], g:gita#command#commit#disable_default_mappings)
  call gita#action#define('commit:do', function('s:action_commit_do'), {
        \ 'description': 'Commit changes',
        \ 'mapping_mode': 'n',
        \ 'options': {},
        \})
  if g:gita#command#commit#disable_default_mappings
    return
  endif
  execute printf(
        \ 'nmap <buffer> <Return> %s',
        \ g:gita#command#commit#default_action_mapping
        \)
  nmap <buffer> <C-c><C-c> <Plug>(gita-commit-do)
  nmap <buffer> <C-c><C-n> <Plug>(gita-commit-new)
  nmap <buffer> <C-c><C-a> <Plug>(gita-commit-amend)
  nmap <buffer> <C-^> <Plug>(gita-status)
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
    if gita#meta#get('winwidth', winwidth(0)) != winwidth(0)
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

function! gita#command#commit#bufname(options) abort
  let options = extend({
        \ 'allow-empty': 0,
        \ 'filenames': [],
        \}, a:options)
  let git = gita#core#get_or_fail()
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
  let options = extend({
        \ 'filenames': [],
        \ 'amend': 0,
        \}, get(a:000, 0, {}))
  let git = gita#core#get_or_fail()
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
  let bufname = gita#command#commit#bufname(options)
  let opener = empty(options.opener)
        \ ? g:gita#command#commit#default_opener
        \ : options.opener
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
  call gita#command#commit#edit(options)
endfunction
function! gita#command#commit#edit(...) abort
  let options = gita#option#cascade('^\%(commit\|status\)$', get(a:000, 0, {}))
  let options['porcelain'] = 1
  let options['dry-run'] = 1
  let options['quiet'] = 1
  let result = gita#command#commit#call(options)
  call gita#meta#set('content_type', 'commit')
  call gita#meta#set('options', s:Dict.omit(options, [
        \ 'force', 'opener', 'porcelain', 'dry-run',
        \]))
  call gita#meta#set('statuses', result.statuses)
  call gita#meta#set('filename', len(result.filenames) == 1 ? result.filenames[0] : '')
  call gita#meta#set('filenames', result.filenames)
  call gita#meta#set('winwidth', winwidth(0))
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
  let git = gita#core#get_or_fail()
  let options = gita#meta#get('options')

  let commit_mode = ''
  if !empty(gita#meta#get('commitmsg_cached'))
    let commitmsg = gita#meta#get('commitmsg_cached')
    call gita#meta#get('commitmsg_cached', [])
    setlocal modified
  elseif !empty(gita#meta#get('commitmsg_saved'))
    let commitmsg = gita#meta#get('commitmsg_saved')
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
        \ commit_mode ==# 'merge' ? ['# This branch is in MERGE mode.'] : [],
        \ commit_mode ==# 'amend' ? ['# This branch is in AMEND mode.'] : [],
        \])
  let statuses = gita#meta#get('statuses', [])
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
          \ 'unknown_description': 'files to index for commit',
          \ 'complete_threshold': g:gita#complete_threshold,
          \})
    call s:parser.add_argument(
          \ '--quiet',
          \ 'be quiet',
          \)
    call s:parser.add_argument(
          \ '--opener', '-o',
          \ 'a way to open a new buffer such as "edit", "split", etc.', {
          \   'type': s:ArgumentParser.types.value,
          \})
    call s:parser.add_argument(
          \ '--author',
          \ 'override author for commit', {
          \   'type': s:ArgumentParser.types.value,
          \})
    call s:parser.add_argument(
          \ '--date',
          \ 'override date for commit', {
          \   'type': s:ArgumentParser.types.value,
          \})
    call s:parser.add_argument(
          \ '--message', '-m',
          \ 'commit message', {
          \   'type': s:ArgumentParser.types.value,
          \})
    call s:parser.add_argument(
          \ '--gpg-sign', '-S',
          \ 'GPG sign commit', {
          \   'type': s:ArgumentParser.types.any,
          \   'conflicts': ['no-gpg-sign'],
          \})
    call s:parser.add_argument(
          \ '--no-gpg-sign',
          \ 'no GPG sign commit', {
          \   'conflicts': ['gpg-sign'],
          \})
    call s:parser.add_argument(
          \ '--amend',
          \ 'amend previous commit',
          \)
    call s:parser.add_argument(
          \ '--all', '-a',
          \ 'commit all changed files',
          \)
    call s:parser.add_argument(
          \ '--allow-empty',
          \ 'allow an empty commit',
          \)
    call s:parser.add_argument(
          \ '--allow-empty-message',
          \ 'allow an empty commit message',
          \)
    call s:parser.add_argument(
          \ '--reset-author',
          \ 'reset author for commit',
          \)
    call s:parser.add_argument(
          \ '--untracked-files', '-u',
          \ 'show untracked files, optional modes: all, normal, no', {
          \   'choices': ['all', 'normal', 'no'],
          \   'on_default': 'all',
          \})
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
  if has_key(options, 'message')
    call gita#command#commit#call(options)
  else
    call gita#command#commit#open(options)
  endif
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
      \ 'disable_default_mappings': 0,
      \})
