let s:V = hita#vital()
let s:List = s:V.import('Data.List')
let s:Dict = s:V.import('Data.Dict')
let s:Path = s:V.import('System.Filepath')
let s:Prompt = s:V.import('Vim.Prompt')
let s:Anchor = s:V.import('Vim.Buffer.Anchor')
let s:Git = s:V.import('Git')
let s:GitInfo = s:V.import('Git.Info')
let s:GitParser = s:V.import('Git.Parser')
let s:GitProcess = s:V.import('Git.Process')
let s:ArgumentParser = s:V.import('ArgumentParser')
let s:entry_offset = 0

function! s:pick_available_options(options) abort
  let options = s:Dict.pick(a:options, [
        \ 'file',
        \ 'porcelain',
        \ 'dry-run',
        \ 'u', 'untracked-files',
        \ 'a', 'all',
        \ 'reset-author',
        \ 'amend',
        \])
  if s:GitInfo.get_git_version() =~# '^-\|^1\.[1-3]\.'
    " remove -u/--untracked-files which requires Git >= 1.4
    let options = s:Dict.omit(options, ['u', 'untracked-files'])
  endif
  return options
endfunction
function! s:get_commit_content(hita, filenames, options) abort
  let options = s:pick_available_options(a:options)
  if !empty(a:filenames)
    let options['--'] = a:filenames
  endif
  let result = hita#execute(a:hita, 'commit', options)
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
  call hita#set_meta('commitmsg_saved', s:get_current_commitmsg())
endfunction
function! s:commit_commitmsg() abort
  let hita = hita#get_or_fail()
  let options = hita#get_meta('options')
  let statuses = hita#get_meta('statuses')
  let staged_statuses = filter(copy(statuses), 'v:val.is_staged')
  if !s:GitInfo.is_merging(hita) && empty(staged_statuses) && get(options, 'allow-empty')
    call hita#throw(
          \ 'An empty commit is now allowed. Add --allow-empty option to allow.',
          \)
  elseif &modified
    call hita#throw(
          \ 'Warning:',
          \ 'You have unsaved changes. Save the changes by ":w" first',
          \)
  endif
  let commitmsg = s:get_current_commitmsg()
  if join(commitmsg) =~# '^\s*$'
    call hita#throw(
          \ 'Warning:',
          \ 'No commit message is written. Write a commit message first',
          \)
  endif

  let options = deepcopy(options)
  let options.file = tempname()
  let options.porcelain = 0
  let options['dry-run'] = 0
  try
    call writefile(commitmsg, options.file)
    call s:get_commit_content(hita, [], options)
    call hita#set_meta('commitmsg_saved', '')
    call hita#set_meta('amend', 0)
  finally
    call delete(options.file)
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
  let statuses = hita#get_meta('statuses', [])
  return index >= 0 ? get(statuses, index, {}) : {}
endfunction
function! s:define_actions() abort
  let action = hita#action#define(function('s:get_entry'))
  " Override 'redraw' action
  function! action.actions.redraw(candidates, ...) abort
    call hita#command#commit#update()
  endfunction

  call hita#action#includes(
        \ g:hita#command#commit#enable_default_mappings, [
        \   'close', 'redraw', 'mapping',
        \   'edit', 'show', 'diff', 'blame', 'browse',
        \])

  if g:hita#command#commit#enable_default_mappings
    silent execute printf(
          \ 'map <buffer> <Return> %s',
          \ g:hita#command#commit#default_action_mapping
          \)
  endif
endfunction

function! s:on_BufReadCmd() abort
  try
    call hita#command#commit#update()
  catch /^\%(vital: Git[:.]\|vim-hita:\)/
    call hita#util#handle_exception()
  endtry
endfunction
function! s:on_BufWriteCmd() abort
  try
    call s:save_commitmsg()
    setlocal nomodified
  catch /^\%(vital: Git[:.]\|vim-hita:\)/
    call hita#util#handle_exception()
  endtry
endfunction
function! s:on_VimResized() abort
  try
    call hita#command#commit#redraw()
  catch /^\%(vital: Git[:.]\|vim-hita:\)/
    call hita#util#handle_exception()
  endtry
endfunction
function! s:on_WinEnter() abort
  try
    if hita#get_meta('winwidth', winwidth(0)) != winwidth(0)
      call hita#command#commit#redraw()
    endif
  catch /^\%(vital: Git[:.]\|vim-hita:\)/
    call hita#util#handle_exception()
  endtry
endfunction
function! s:on_WinLeave() abort
  if exists('w:_vim_hita_commit_QuitPre')
    unlet w:_vim_hita_commit_QuitPre
    try
      if !&modified && s:Prompt.confirm('Do you want to commit changes?', 'y')
        call s:commit_commitmsg()
      endif
    catch /^\%(vital: Git[:.]\|vim-hita:\)/
      call hita#util#handle_exception()
    endtry
  endif
endfunction
function! s:on_QuitPre() abort
  let w:_vim_hita_commit_QuitPre = 1
endfunction
function! s:on_HitaStatusModified() abort
  try
    let winnum = winnr()
    keepjump windo
          \ if &filetype ==# 'hita-commit' |
          \   call hita#command#commit#update() |
          \ endif
    execute printf('keepjump %dwincmd w', winnum)
  catch /^\%(vital: Git[:.]\|vim-hita:\)/
    call hita#util#handle_exception()
  endtry
endfunction

function! hita#command#commit#bufname(...) abort
  let options = hita#option#init('commit', get(a:000, 0, {}), {
        \ 'filenames': [],
        \ 'amend': 0,
        \})
  let hita = hita#get_or_fail()
  return hita#autocmd#bufname(hita, {
        \ 'filebase': 0,
        \ 'content_type': 'commit',
        \ 'extra_options': [
        \   options.amend ? 'amend': '',
        \   empty(options.filenames) ? '' : 'partial',
        \ ],
        \ 'commitish': '',
        \ 'path': '',
        \})
endfunction
function! hita#command#commit#call(...) abort
  let options = hita#option#init('commit', get(a:000, 0, {}), {
        \ 'filenames': [],
        \ 'amend': 0,
        \})
  let hita = hita#get_or_fail()
  if !empty(options.filenames)
    let filenames = map(
          \ copy(options.filenames),
          \ 'hita#variable#get_valid_filename(v:val)',
          \)
  else
    let filenames = []
  endif
  let content = s:get_commit_content(hita, filenames, options)
  let result = {
        \ 'filenames': filenames,
        \ 'content': content,
        \ 'amend': options.amend,
        \}
  if get(options, 'porcelain')
    let result.statuses = hita#command#status#parse_statuses(hita, content)
  endif
  return result
endfunction
function! hita#command#commit#open(...) abort
  let options = extend({
        \ 'opener': '',
        \}, get(a:000, 0, {}))
  let options['porcelain'] = 1
  let options['dry-run'] = 1
  let result = hita#command#commit#call(options)
  let opener = empty(options.opener)
        \ ? g:hita#command#commit#default_opener
        \ : options.opener
  let bufname = hita#command#commit#bufname(options)
  call hita#util#buffer#open(bufname, {
        \ 'opener': opener,
        \ 'group': 'manipulation_panel',
        \})
  call hita#set_meta('content_type', 'commit')
  call hita#set_meta('options', s:Dict.omit(options, ['force']))
  call hita#set_meta('amend', result.amend)
  call hita#set_meta('statuses', result.statuses)
  call hita#set_meta('filename', len(result.filenames) == 1 ? result.filenames[0] : '')
  call hita#set_meta('filenames', result.filenames)
  call hita#set_meta('winwidth', winwidth(0))
  call s:define_actions()
  augroup vim_hita_internal_commit
    autocmd! * <buffer>
    autocmd BufReadCmd <buffer> call s:on_BufReadCmd()
    autocmd BufWriteCmd <buffer> call s:on_BufWriteCmd()
    autocmd VimResized <buffer> call s:on_VimResized()
    autocmd WinEnter   <buffer> call s:on_WinEnter()
    autocmd WinLeave   <buffer> call s:on_WinLeave()
    autocmd QuitPre    <buffer> call s:on_QuitPre()
  augroup END
  " NOTE:
  " Vim.Buffer.Anchor.register use WinLeave thus it MUST called after autocmd
  " of this buffer has registered.
  call s:Anchor.register()
  " the following options are required so overwrite everytime
  setlocal filetype=hita-commit
  setlocal buftype=acwrite nobuflisted
  setlocal modifiable
  call hita#command#commit#redraw()
endfunction
function! hita#command#commit#update(...) abort
  if &filetype !=# 'hita-commit'
    call hita#throw('update() requires to be called in a hita-commit buffer')
  endif
  let options = get(a:000, 0, {})
  let options['porcelain'] = 1
  let options['dry-run'] = 1
  let result = hita#command#commit#call(options)
  call hita#set_meta('content_type', 'commit')
  call hita#set_meta('options', s:Dict.omit(options, ['force']))
  call hita#set_meta('amend', result.amend)
  call hita#set_meta('statuses', result.statuses)
  call hita#set_meta('filename', len(result.filenames) == 1 ? result.filenames[0] : '')
  call hita#set_meta('filenames', result.filenames)
  call hita#set_meta('winwidth', winwidth(0))
  call hita#command#commit#redraw()
endfunction
function! hita#command#commit#redraw() abort
  if &filetype !=# 'hita-commit'
    call hita#throw('redraw() requires to be called in a hita-commit buffer')
  endif
  let hita = hita#get_or_fail()
  let amend = hita#get_meta('amend')

  let commit_mode = ''
  if !empty(hita#get_meta('commitmsg_cached'))
    let commitmsg = hita#get_meta('commitmsg_cached')
    call hita#get_meta('commitmsg_cached', [])
    setlocal modified
  elseif !empty(hita#get_meta('commitmsg_saved'))
    let commitmsg = hita#get_meta('commitmsg_saved')
  elseif s:GitInfo.is_merging(hita)
    let commitmsg = s:GitInfo.get_merge_msg(hita)
    let commit_mode = 'merge'
  elseif amend
    let commitmsg = s:GitInfo.get_last_commitmsg(hita)
    let commit_mode = 'amend'
  else
    let commitmsg = ['']
  endif

  let prologue = s:List.flatten([
        \ g:hita#command#commit#show_status_string_in_prologue
        \   ? ['# ' . hita#command#status#get_statusline_string() . ' | Press ? to toggle a mapping help']
        \   : [],
        \ hita#action#mapping#get_visibility()
        \   ? map(hita#action#get_mapping_help(), '"# | " . v:val')
        \   : [],
        \ commit_mode ==# 'merge' ? ['# This branch is in MERGE mode.'] : [],
        \ commit_mode ==# 'amend' ? ['# This branch is in AMEND mode.'] : [],
        \])
  let statuses = hita#get_meta('statuses', [])
  let contents = map(
        \ copy(statuses),
        \ 's:format_entry(v:val)'
        \)
  let s:entry_offset = len(prologue)
  call hita#util#buffer#edit_content(
        \ commitmsg + prologue + contents
        \)
endfunction

function! s:get_parser() abort
  if !exists('s:parser') || g:hita#develop
    let s:parser = s:ArgumentParser.new({
          \ 'name': 'Hita commit',
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
function! hita#command#commit#command(...) abort
  let parser  = s:get_parser()
  let options = call(parser.parse, a:000, parser)
  if empty(options)
    return
  endif
  " extend default options
  let options = extend(
        \ deepcopy(g:hita#command#commit#default_options),
        \ options,
        \)
  call hita#command#commit#open(options)
endfunction
function! hita#command#commit#complete(...) abort
  let parser = s:get_parser()
  return call(parser.complete, a:000, parser)
endfunction
function! hita#command#commit#define_highlights() abort
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
function! hita#command#commit#define_syntax() abort
  syntax match HitaStaged     /^# [ MADRC][ MD]/hs=s+2,he=e-1 contains=ALL
  syntax match HitaUnstaged   /^# [ MADRC][ MD]/hs=s+3 contains=ALL
  syntax match HitaStaged     /^# [ MADRC]\s.*$/hs=s+5 contains=ALL
  syntax match HitaUnstaged   /^# .[MDAU?].*$/hs=s+5 contains=ALL
  syntax match HitaIgnored    /^# !!\s.*$/hs=s+2
  syntax match HitaUntracked  /^# ??\s.*$/hs=s+2
  syntax match HitaConflicted /^# \%(DD\|AU\|UD\|UA\|DU\|AA\|UU\)\s.*$/hs=s+2
  syntax match HitaComment    /^# .*$/ contains=ALL
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

augroup vim_hita_internal_commit_update
  autocmd!
  autocmd User HitaStatusModified call s:on_HitaStatusModified()
augroup END

call hita#util#define_variables('command#commit', {
      \ 'default_options': { 'untracked-files': 1 },
      \ 'default_opener': 'botright 10 split',
      \ 'default_action_mapping': '<Plug>(hita-edit)',
      \ 'enable_default_mappings': 1,
      \ 'show_status_string_in_prologue': 1,
      \})
