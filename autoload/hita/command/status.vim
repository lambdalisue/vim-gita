let s:save_cpo = &cpo
set cpo&vim

let s:V = hita#vital()
let s:List = s:V.import('Data.List')
let s:Dict = s:V.import('Data.Dict')
let s:Anchor = s:V.import('Vim.Buffer.Anchor')
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

function! s:format_entry(entry) abort
  return a:entry.record
endfunction
function! s:get_entry(index) abort
  let index = a:index - s:entry_offset
  let statuses = hita#meta#get('statuses', {})
  return index >= 0 ? get(get(statuses, 'all', []), index, {}) : {}
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

function! hita#command#status#call(...) abort
  let options = extend({
        \ 'porcelain': 1,
        \ 'untracked-files': 1,
        \}, get(a:000, 0, {}))
  let hita = hita#core#get()
  if hita.fail_on_disabled()
    return [[], options]
  endif
  " remove -u/--untracked-files if the version of git is lower than or equal to 1.3
  if hita.git.get_version() =~# '-\|^1\.[1-3]\.'
    let options = s:Dict.omit(options, ['u', 'untracked-files'])
  endif
  try
    let result = hita#operation#exec(hita, 'status', s:Dict.pick(options, [
        \ '--',
        \ 'porcelain',
        \ 'u', 'untracked-files',
        \ 'ignored',
        \ 'ignore-submodules',
        \])
        \)
    if result.status
      call hita#throw(result.stdout)
    endif
    return [hita#util#status#parse(result.stdout), options]
  catch /^vim-hita:/
    call hita#util#handle_exception(v:exception)
    return [[], options]
  endtry
endfunction
function! hita#command#status#open(...) abort
  let options = extend({
        \ 'opener': '',
        \ 'cache': 1,
        \}, get(a:000, 0, {}))
  let [statuses, options] = hita#command#status#call(options)
  if empty(statuses)
    return
  endif
  let opener = empty(options.opener)
        \ ? g:hita#command#status#default_opener
        \ : options.opener
  let hita = hita#core#get()
  let bufname = printf('hita-status:%s',
        \ fnamemodify(hita.git.repository, ':h:t'),
        \)
  call hita#util#buffer#open(bufname, {
        \ 'opener': opener . (options.cache ? '' : '!'),
        \ 'group': 'manipulation_panel',
        \})
  call hita#meta#set('statuses', statuses)
  call hita#meta#set('options', options)
  call hita#meta#set('winwidth', winwidth(0))
  call s:define_plugin_mappings()
  if g:hita#command#status#enable_default_mappings
    call s:define_default_mappings()
  endif
  augroup vim_hita_status
    autocmd! * <buffer>
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
  let options = extend(
        \ hita#meta#get('options', {}),
        \ get(a:000, 0, {})
        \)
  let [statuses, options] = hita#command#status#call(options)
  if empty(statuses)
    return
  endif
  call hita#meta#set('statuses', statuses)
  call hita#meta#set('options', options)
  call hita#meta#set('winwidth', winwidth(0))
  call hita#command#status#redraw()
endfunction
function! hita#command#status#redraw() abort
  if &filetype !=# 'hita-status'
    call hita#throw(
          \ 'redraw() requires to be called in a hita-status buffer'
          \)
  endif
  let prologue = s:List.flatten([
        \ g:hita#command#status#show_status_string_in_prologue
        \   ? [hita#command#status#get_status_string() . ' | Press ? to toggle a mapping help']
        \   : [],
        \ s:get_current_mapping_visibility()
        \   ? map(hita#util#mapping#help(s:MAPPING_TABLE), '"| " . v:val')
        \   : []
        \])
  redraw
  echo 'Formatting status entries to display ...'
  let statuses = hita#meta#get('statuses', {})
  let contents = map(
        \ copy(get(statuses, 'all', [])),
        \ 's:format_entry(v:val)'
        \)
  let s:entry_offset = len(prologue)
  call hita#util#buffer#edit_content(extend(prologue, contents))
  redraw | echo
endfunction

function! s:on_VimResized() abort
  call hita#command#status#redraw()
endfunction
function! s:on_WinEnter() abort
  if hita#meta#get('winwidth', winwidth(0)) != winwidth(0)
    call hita#command#status#redraw()
  endif
endfunction

function! s:action(name, ...) range abort
  let fname = printf('s:action_%s', a:name)
  if !exists('*' . fname)
    call hita#throw(printf(
          \ 'Unknown action name "%s" is called.',
          \ a:name,
          \))
  endif
  " Call action function with a:firstline and a:lastline propagation
  call call(fname, extend([a:firstline, a:lastline], a:000))
endfunction
function! s:action_edit(startline, endline, ...) abort
  let opener = get(a:000, 0, '')
  let opener = empty(opener)
        \ ? g:hita#command#status#default_entry_opener
        \ : opener
  let [opener, anchor] = get(
        \ g:hita#command#status#entry_openers,
        \ opener, ['edit', 1],
        \)
  let entries = []
  for n in range(a:startline, a:endline)
    call add(entries, s:get_entry(n - 1))
  endfor
  call filter(entries, '!empty(v:val)')
  if !empty(entries) && anchor
    call s:Anchor.focus()
  endif
  for entry in entries
    call hita#command#open#open({
          \ 'commit': 'WORKTREE',
          \ 'filename': get(entry, 'path2', entry.path),
          \ 'opener': opener,
          \})
  endfor
endfunction
function! s:action_redraw(startline, endline, ...) abort
  call hita#command#status#redraw()
endfunction
function! s:action_toggle_mapping_visibility(startline, endline, ...) abort
  call s:set_current_mapping_visibility(!s:get_current_mapping_visibility())
  call hita#command#status#redraw()
endfunction

function! s:get_parser() abort
  if !exists('s:parser') || g:hita#develop
    let s:parser = s:ArgumentParser.new({
          \ 'name': 'Hita[!] list',
          \ 'description': [
          \   'List status of a git repository',
          \ ],
          \})
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

function! hita#command#status#get_status_string() abort
  return 'Hita'
endfunction

call hita#define_variables('command#status', {
      \ 'default_options': {},
      \ 'default_lookup': '',
      \ 'default_mapping_visibility': 0,
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
      \ 'show_status_string_in_prologue': 1,
      \})

let &cpo = s:save_cpo
unlet! s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
