let s:V = hita#vital()
let s:List = s:V.import('Data.List')
let s:Dict = s:V.import('Data.Dict')
let s:Path = s:V.import('System.Filepath')
let s:Anchor = s:V.import('Vim.Buffer.Anchor')
let s:GitCore = s:V.import('VCS.Git.Core')
let s:StatusParser = s:V.import('VCS.Git.StatusParser')
let s:ArgumentParser = s:V.import('ArgumentParser')
let s:MAPPING_TABLE = {
      \ '<Plug>(hita-quit)': 'Close the buffer',
      \ '<Plug>(hita-redraw)': 'Redraw the buffer',
      \ '<Plug>(hita-toggle-mapping-visibility)': 'Toggle mapping visibility',
      \ '<Plug>(hita-edit)': 'Open a selected gist',
      \ '<Plug>(hita-edit-above)': 'Open a selected file in an above window',
      \ '<Plug>(hita-edit-below)': 'Open a selected file in a below window',
      \ '<Plug>(hita-edit-left)': 'Open a selected file in a left window',
      \ '<Plug>(hita-edit-right)': 'Open a selected file in a right window',
      \ '<Plug>(hita-edit-tab)': 'Open a selected file in a next tab',
      \ '<Plug>(hita-edit-preview)': 'Open a selected file in a preview window',
      \}
let s:entry_offset = 0

function! s:get_git_version() abort
  if !exists('s:git_version')
    let s:git_version = s:GitCore.get_version()
  endif
  return s:git_version
endfunction
function! s:pick_available_options(options) abort
  let options = s:Dict.pick(a:options, [
        \ 'porcelain',
        \ 'ignored',
        \ 'ignore-submodules',
        \ 'u', 'untracked-files',
        \])
  if s:get_git_version() =~# '^-\|^1\.[1-3]\.'
    " remove -u/--untracked-files which requires Git >= 1.4
    let options = s:Dict.omit(options, ['u', 'untracked-files'])
  endif
  return options
endfunction
function! s:get_status_content(hita, filenames, options) abort
  let options = s:pick_available_options(a:options)
  if !empty(a:filenames)
    let options['--'] = map(
          \ copy(a:filenames),
          \ 'a:hita.get_relative_path(v:val)'
          \)
  endif
  let result = hita#operation#exec(a:hita, 'status', options)
  if result.status
    call hita#throw(result.stdout)
  endif
  return split(result.stdout, '\r\?\n')
endfunction

function! s:extend_status(hita, status) abort
  let a:status.path = a:hita.get_absolute_path(a:status.path)
  if has_key(a:status, 'path2')
    let a:status.path2 = a:hita.get_absolute_path(a:status.path2)
  endif
  return a:status
endfunction
function! s:compare_statuses(lhs, rhs) abort
  if a:lhs.path == a:rhs.path
    return 0
  elseif a:lhs.path > a:rhs.path
    return 1
  else
    return -1
  endif
endfunction
function! s:parse_statuses(hita, content, options) abort
  let statuses = s:StatusParser.parse(join(a:content, "\n"), {
        \ 'fail_silently': 1,
        \})
  if get(statuses, 'status')
    call hita#throw(statuses.stdout)
  endif
  call map(statuses.all, 's:extend_status(a:hita, v:val)')
  return statuses.all
endfunction

function! s:get_entry(index) abort
  let index = a:index - s:entry_offset
  let statuses = hita#core#get_meta('statuses', [])
  return index >= 0 ? get(statuses, index, {}) : {}
endfunction
function! s:format_entry(entry) abort
  return a:entry.record
endfunction
function! s:get_statusline_string(hita) abort
  let meta = a:hita.git.get_meta()
  let name = meta.local.name
  let branch = meta.local.branch_name
  let remote_name = meta.remote.name
  let remote_branch = meta.remote.branch_name
  let mode = a:hita.git.get_mode()
  let is_connected = !(empty(remote_name) || empty(remote_branch))

  let branchinfo = is_connected
        \ ? printf('%s/%s <> %s/%s', name, branch, remote_name, remote_branch)
        \ : printf('%s/%s', name, branch)
  let connection = ''
  if is_connected
    let outgoing = a:hita.git.count_commits_ahead_of_remote()
    let incoming = a:hita.git.count_commits_behind_remote()
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
function! s:get_current_mapping_visibility() abort
  if exists('s:current_mapping_visibility')
    return s:current_mapping_visibility
  endif
  let s:current_mapping_visibility =
        \ g:hita#command#status#default_mapping_visibility
  return s:current_mapping_visibility
endfunction
function! s:set_current_mapping_visibility(value) abort
  let s:current_mapping_visibility = a:value
endfunction
function! s:define_plugin_mappings() abort
  nnoremap <buffer><silent> <Plug>(hita-quit)
        \ :<C-u>q<CR>
  nnoremap <buffer><silent> <Plug>(hita-redraw)
        \ :call <SID>action('redraw')<CR>
  nnoremap <buffer><silent> <Plug>(hita-toggle-mapping-visibility)
        \ :call <SID>action('toggle_mapping_visibility')<CR>

  noremap <buffer><silent> <Plug>(hita-edit)
        \ :call <SID>action('edit')<CR>
  noremap <buffer><silent> <Plug>(hita-edit-above)
        \ :call <SID>action('edit', 'above')<CR>
  noremap <buffer><silent> <Plug>(hita-edit-below)
        \ :call <SID>action('edit', 'below')<CR>
  noremap <buffer><silent> <Plug>(hita-edit-left)
        \ :call <SID>action('edit', 'left')<CR>
  noremap <buffer><silent> <Plug>(hita-edit-right)
        \ :call <SID>action('edit', 'right')<CR>
  noremap <buffer><silent> <Plug>(hita-edit-tab)
        \ :call <SID>action('edit', 'tab')<CR>
  noremap <buffer><silent> <Plug>(hita-edit-preview)
        \ :call <SID>action('edit', 'preview')<CR>
endfunction
function! s:define_default_mappings() abort
  nmap <buffer> q <Plug>(hita-quit)
  nmap <buffer> ? <Plug>(hita-toggle-mapping-visibility)
  nmap <buffer> <C-l> <Plug>(hita-redraw)
  map <buffer> <Return> <Plug>(hita-edit)
  map <buffer> ee <Plug>(hita-edit)
  map <buffer> EE <Plug>(hita-edit-right)
  map <buffer> tt <Plug>(hita-edit-tab)
  map <buffer> pp <Plug>(hita-edit-preview)
endfunction

function! s:action(name, ...) range abort
  let fname = printf('s:action_%s', a:name)
  if !exists('*' . fname)
    call hita#throw(printf('Unknown action name "%s" is called.', a:name))
  endif
  let entries = []
  for n in range(a:firstline, a:lastline)
    call add(entries, s:get_entry(n - 1))
  endfor
  call filter(entries, '!empty(v:val)')
  call call(fname, extend([entries], a:000))
endfunction
function! s:action_edit(candidates, ...) abort
  let opener = get(a:000, 0, '')
  let opener = empty(opener)
        \ ? g:hita#command#status#default_entry_opener
        \ : opener
  let [opener, anchor] = get(
        \ g:hita#command#status#entry_openers,
        \ opener, ['edit', 1],
        \)
  if !empty(a:candidates) && anchor
    call s:Anchor.focus()
  endif
  for entry in a:candidates
    let bufname = s:Path.realpath(get(entry, 'path2', entry.path))
    let bufname = s:Path.relpath(bufname)
    call hita#util#buffer#open(bufname, {
          \ 'opener': opener,
          \})
  endfor
endfunction
function! s:action_redraw(candidates, ...) abort
  call hita#command#status#redraw()
endfunction
function! s:action_toggle_mapping_visibility(candidates, ...) abort
  call s:set_current_mapping_visibility(!s:get_current_mapping_visibility())
  call hita#command#status#redraw()
endfunction

function! s:on_VimResized() abort
  call hita#command#status#redraw()
endfunction
function! s:on_WinEnter() abort
  if hita#core#get_meta('winwidth', winwidth(0)) != winwidth(0)
    call hita#command#status#redraw()
  endif
endfunction

function! hita#command#status#bufname(...) abort
  let options = extend({
        \ 'filenames': [],
        \}, get(a:000, 0, {}))
  call hita#option#assign_options(options, 'status')
  let hita = hita#core#get()
  try
    call hita.fail_on_disabled()
  catch /^vim-hita:/
    call hita#util#handle_exception(v:exception)
    return
  endtry
  return printf('hita-status:%s%s',
        \ hita.get_repository_name(),
        \ empty(options.filenames) ? '' : ':partial'
        \)
endfunction
function! hita#command#status#call(...) abort
  let options = extend({
        \ 'filenames': '',
        \}, get(a:000, 0, {}))
  call hita#option#assign_options(options, 'status')
  let hita = hita#core#get()
  try
    call hita.fail_on_disabled()
    if !empty(options.filenames)
      let filenames = map(
            \ copy(options.filenames),
            \ 'hita#variable#get_valid_filename(v:val)',
            \)
    else
      let filenames = []
    endif
    let content = s:get_status_content(hita, filenames, options)
    let result = {
          \ 'filenames': filenames,
          \ 'content': content,
          \}
    if get(options, 'porcelain')
      let result.statuses = sort(
            \ s:parse_statuses(hita, content, options),
            \ function('s:compare_statuses'),
            \)
    endif
    return result
  catch /^vim-hita:/
    call hita#util#handle_exception(v:exception)
    return {}
  endtry
endfunction
function! hita#command#status#open(...) abort
  let options = extend({
        \ 'opener': '',
        \}, get(a:000, 0, {}))
  let options['porcelain'] = 1
  let result = hita#command#status#call(options)
  if empty(result)
    return
  endif
  let opener = empty(options.opener)
        \ ? g:hita#command#status#default_opener
        \ : options.opener
  let bufname = hita#command#status#bufname(options)
  call hita#util#buffer#open(bufname, {
        \ 'opener': opener,
        \ 'group': 'manipulation_panel',
        \})
  call hita#core#set_meta('content_type', 'status')
  call hita#core#set_meta('options', s:Dict.omit(options, ['force']))
  call hita#core#set_meta('statuses', result.statuses)
  call hita#core#set_meta('filenames', result.filenames)
  call hita#core#set_meta('winwidth', winwidth(0))
  call s:define_plugin_mappings()
  if g:hita#command#status#enable_default_mappings
    call s:define_default_mappings()
  endif
  augroup vim_hita_status
    autocmd! * <buffer>
    autocmd BufReadCmd <buffer>
          \ call hita#command#status#update() |
          \ setlocal filetype=hita-status
    autocmd VimResized <buffer> call s:on_VimResized()
    autocmd WinEnter   <buffer> call s:on_WinEnter()
  augroup END
  setlocal nonumber nolist nowrap nospell nofoldenable textwidth=0
  setlocal foldcolumn=0 colorcolumn=0
  setlocal cursorline
  setlocal buftype=nofile nobuflisted
  setlocal nomodifiable
  setlocal filetype=hita-status
  call hita#command#status#redraw()
endfunction
function! hita#command#status#update(...) abort
  if &filetype !=# 'hita-status'
    call hita#throw(
          \ 'update() requires to be called in a hita-status buffer'
          \)
  endif
  let options = get(a:000, 0, {})
  let options['porcelain'] = 1
  let result = hita#command#status#call(options)
  if empty(result)
    return
  endif
  call hita#core#set_meta('content_type', 'status')
  call hita#core#set_meta('options', s:Dict.omit(options, ['force']))
  call hita#core#set_meta('statuses', result.statuses)
  call hita#core#set_meta('filenames', result.filenames)
  call hita#core#set_meta('winwidth', winwidth(0))
  call hita#command#status#redraw()
endfunction
function! hita#command#status#redraw() abort
  if &filetype !=# 'hita-status'
    call hita#throw(
          \ 'redraw() requires to be called in a hita-status buffer'
          \)
  endif
  let hita = hita#core#get()
  let prologue = s:List.flatten([
        \ g:hita#command#status#show_status_string_in_prologue
        \   ? [s:get_statusline_string(hita) . ' | Press ? to toggle a mapping help']
        \   : [],
        \ s:get_current_mapping_visibility()
        \   ? map(hita#util#mapping#help(s:MAPPING_TABLE), '"| " . v:val')
        \   : []
        \])
  redraw
  let statuses = hita#core#get_meta('statuses', [])
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
  highlight default link HitaImportant  Keyword
endfunction
function! hita#command#status#define_syntax() abort
  syntax match HitaStaged     /\v^[ MADRC][ MD]/he=e-1 contains=ALL
  syntax match HitaUnstaged   /\v^[ MADRC][ MD]/hs=s+1 contains=ALL
  syntax match HitaStaged     /\v^[ MADRC]\s.*$/hs=s+3 contains=ALL
  syntax match HitaUnstaged   /\v^.[MDAU?].*$/hs=s+3 contains=ALL
  syntax match HitaIgnored    /\v^\!\!\s.*$/
  syntax match HitaUntracked  /\v^\?\?\s.*$/
  syntax match HitaConflicted /\v^%(DD|AU|UD|UA|DU|AA|UU)\s.*$/
  syntax match HitaComment    /\v^.*$/ contains=ALL
  syntax match HitaBranch     /\v`[^`]{-}`/hs=s+1,he=e-1
  syntax match HitaImportant  /\vREBASE-[mi] \d\/\d/
  syntax match HitaImportant  /\vREBASE \d\/\d/
  syntax match HitaImportant  /\vAM \d\/\d/
  syntax match HitaImportant  /\vAM\/REBASE \d\/\d/
  syntax match HitaImportant  /\v(MERGING|CHERRY-PICKING|REVERTING|BISECTING)/
endfunction

function! hita#command#status#get_statusline_string() abort
  let hita = hita#core#get()
  if hita.is_enabled()
    return s:get_statusline_string(hita)
  else
    return ''
  endif
endfunction

call hita#define_variables('command#status', {
      \ 'default_options': { 'untracked-files': 1 },
      \ 'default_opener': 'topleft 15 split',
      \ 'default_entry_opener': 'edit',
      \ 'entry_openers': {
      \   'edit':    ['edit', 1],
      \   'above':   ['leftabove new', 1],
      \   'below':   ['rightbelow new', 1],
      \   'left':    ['leftabove vnew', 1],
      \   'right':   ['rightbelow vnew', 1],
      \   'tab':     ['tabnew', 0],
      \   'preview': ['pedit', 0],
      \ },
      \ 'enable_default_mappings': 1,
      \ 'default_mapping_visibility': 0,
      \ 'show_status_string_in_prologue': 1,
      \})
