let s:V = gita#vital()
let s:Dict = s:V.import('Data.Dict')

function! s:get_entry(index) abort
  let blamemeta = gita#command#blame#get_blamemeta_or_fail()
  let lineinfo = get(blamemeta.lineinfos, a:index, {})
  if empty(lineinfo)
    return {}
  endif
  return blamemeta.chunks[lineinfo.chunkref]
endfunction
function! s:define_actions() abort
  let action = gita#action#define(function('s:get_entry'))

  call gita#action#includes(
        \ g:gita#command#blame#view#enable_default_mappings, [
        \   'close', 'redraw',
        \])

  if g:gita#command#blame#view#enable_default_mappings
    execute printf(
          \ 'map <buffer> <Return> %s',
          \ g:gita#command#blame#navi#default_action_mapping
          \)
  endif
endfunction

function! s:on_BufReadCmd() abort
  try
    let winnum = winnr()
    let commit = gita#get_meta('commit')
    let filename = gita#get_meta('filename')
    call gita#command#blame#open({
          \ 'commit': commit,
          \ 'filename': filename,
          \})
    execute printf('keepjumps %dwincmd w', winnum)
  catch /^\%(vital: Git[:.]\|vim-gita:\)/
    call gita#util#handle_exception()
  endtry
endfunction

function! gita#command#blame#view#bufname(...) abort
  let options = gita#option#init('blame-view', get(a:000, 0, {}), {
        \ 'commit': '',
        \ 'filename': '',
        \})
  let git = gita#get_or_fail()
  let commit = gita#variable#get_valid_range(options.commit, {
        \ '_allow_empty': 1,
        \})
  let filename = gita#variable#get_valid_filename(options.filename)
  return gita#autocmd#bufname(git, {
        \ 'filebase': 0,
        \ 'content_type': 'blame-view',
        \ 'extra_options': [],
        \ 'commitish': commit,
        \ 'path': filename,
        \})
endfunction
function! gita#command#blame#view#_open(blameobj, ...) abort
  " NOTE:
  " This function should be called only from gita#command#blame#open so that
  " options.commit, options.filename should be valid.
  let options = extend({
        \ 'opener': '',
        \ 'commit': '',
        \ 'filename': '',
        \}, get(a:000, 0, {}))
  let opener = empty(options.opener)
        \ ? g:gita#command#blame#view#default_opener
        \ : options.opener
  let bufname = gita#command#blame#view#bufname(options)
  call gita#util#buffer#open(bufname, {
        \ 'group': 'blame_view',
        \ 'opener': opener,
        \})
  " gita#command#blame#view#_edit() will be called by
  " gita#command#blame#open() later so store 'blameobj' reference into meta
  call gita#set_meta('content_type', 'blame-view')
  call gita#set_meta('blameobj', a:blameobj)
  call gita#set_meta('commit', options.commit)
  call gita#set_meta('filename', options.filename)
endfunction
function! gita#command#blame#view#_edit() abort
  call gita#command#blame#get_blameobj_or_fail()
  call s:define_actions()
  augroup vim_gita_internal_blame_view
    autocmd! * <buffer>
    autocmd BufReadCmd <buffer> call s:on_BufReadCmd()
  augroup END
  filetype detect
  setlocal nonumber nowrap nofoldenable foldcolumn=0
  setlocal buftype=nowrite noswapfile nobuflisted
  setlocal nomodifiable
  setlocal scrollopt=ver
  call gita#command#blame#view#redraw()
endfunction
function! gita#command#blame#view#redraw() abort
  let blamemeta = gita#command#blame#get_blamemeta_or_fail()
  call gita#util#buffer#edit_content(blamemeta.view_content)
  call gita#command#blame#display_pseudo_separators(blamemeta.separators)
endfunction

call gita#util#define_variables('command#blame#view', {
      \ 'default_opener': 'edit',
      \ 'default_action_mapping': '<Plug>(gita-show)',
      \ 'enable_default_mappings': 1,
      \})
