let s:V = gita#vital()
let s:Dict = s:V.import('Data.Dict')
let s:Guard = s:V.import('Vim.Guard')
let s:Anchor = s:V.import('Vim.Buffer.Anchor')

function! s:define_actions() abort
  call gita#action#includes(
        \ g:gita#command#blame#view#enable_default_mappings, [
        \   'redraw',
        \])
endfunction

function! s:on_BufReadCmd() abort
  try
    call gita#command#blame#view#_edit()
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
        \ 'backward': '',
        \}, get(a:000, 0, {}))
  let opener = empty(options.opener)
        \ ? g:gita#command#blame#view#default_opener
        \ : options.opener
  let bufname = gita#command#blame#view#bufname(options)
  silent call gita#util#buffer#open(bufname, {
        \ 'group': 'blame_view',
        \ 'opener': opener,
        \})
  " gita#command#blame#view#_edit() will be called by
  " gita#command#blame#open() later so store 'blameobj' reference into meta
  let a:blameobj.view_bufnum = bufnr('%')
  call gita#set_meta('content_type', 'blame-view')
  call gita#set_meta('blameobj', a:blameobj)
  call gita#set_meta('commit', options.commit)
  call gita#set_meta('filename', options.filename)
  if !empty(options.backward) || empty(gita#get_meta('backward'))
    call gita#set_meta('backward', options.backward)
  endif
endfunction
function! gita#command#blame#view#_edit() abort
  call gita#command#blame#_get_blameobj_or_fail()
  call s:define_actions()
  augroup vim_gita_internal_blame_view
    autocmd! * <buffer>
    autocmd BufReadCmd <buffer> nested call s:on_BufReadCmd()
  augroup END
  filetype detect
  setlocal nonumber norelativenumber nowrap nofoldenable foldcolumn=0
  setlocal buftype=nowrite noswapfile nobuflisted
  setlocal nomodifiable
  setlocal scrollopt=ver
  call gita#command#blame#view#redraw()
endfunction
function! gita#command#blame#view#redraw() abort
  let blamemeta = gita#command#blame#_get_blamemeta_or_fail()
  call gita#util#buffer#edit_content(blamemeta.view_content)
  call gita#command#blame#_set_pseudo_separators(blamemeta.separators)
endfunction

call gita#util#define_variables('command#blame#view', {
      \ 'default_opener': 'edit',
      \ 'enable_default_mappings': 1,
      \})
