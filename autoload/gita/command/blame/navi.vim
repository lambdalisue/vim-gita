let s:V = gita#vital()
let s:Dict = s:V.import('Data.Dict')
let s:Guard = s:V.import('Vim.Guard')
let s:Anchor = s:V.import('Vim.Buffer.Anchor')

function! s:define_actions() abort
  let action = gita#command#blame#_define_actions()

  nmap <buffer> <C-g> <Plug>(gita-blame-echo)
  nmap <buffer> <CR> <Plug>(gita-blame-enter)
  nmap <buffer> <Backspace> <Plug>(gita-blame-backward)

  call gita#action#includes(
        \ g:gita#command#blame#navi#enable_default_mappings, [
        \   'redraw',
        \   'edit', 'show', 'diff', 'browse',
        \])
endfunction

function! s:on_CursorMoved() abort
  try
    " Restrict cursor movement to mimic linenum columns
    let blamemeta = gita#command#blame#_get_blamemeta_or_fail()
    let linenum_width = blamemeta.linenum_width
    let column = col('.')
    if column <= linenum_width + 1
      call setpos('.', [0, line('.'), linenum_width + 2, 0])
    endif
  catch
    " fail silently
  endtry
endfunction
function! s:on_BufReadCmd() abort
  try
    call gita#command#blame#navi#_edit()
  catch /^\%(vital: Git[:.]\|vim-gita:\)/
    call gita#util#handle_exception()
  endtry
endfunction

function! gita#command#blame#navi#bufname(...) abort
  let options = gita#option#init('blame-navi', get(a:000, 0, {}), {
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
        \ 'content_type': 'blame-navi',
        \ 'extra_options': [],
        \ 'commitish': commit,
        \ 'path': filename,
        \})
endfunction
function! gita#command#blame#navi#_open(blameobj, ...) abort
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
        \ ? g:gita#command#blame#navi#default_opener
        \ : options.opener
  let bufname = gita#command#blame#navi#bufname(options)
  silent call gita#util#buffer#open(bufname, {
        \ 'group': 'blame_navi',
        \ 'opener': opener,
        \})
  " gita#command#blame#navi#_edit() will be called by
  " gita#command#blame#open() later so store 'blameobj' reference into meta
  let a:blameobj.navi_bufnum = bufnr('%')
  call gita#set_meta('content_type', 'blame-navi')
  call gita#set_meta('blameobj', a:blameobj)
  call gita#set_meta('commit', options.commit)
  call gita#set_meta('filename', options.filename)
  if !empty(options.backward) || empty(gita#get_meta('backward'))
    call gita#set_meta('backward', options.backward)
  endif
endfunction
function! gita#command#blame#navi#_edit() abort
  let blameobj = gita#command#blame#_get_blameobj_or_fail()
  if !has_key(blameobj, 'blamemeta') || gita#get_meta('winwidth') != winwidth(0)
    " Construct 'blamemeta' from 'blameobj'. It is time-consuming process.
    " Store constructed 'blamemeta' in 'blameobj' so that blame-view buffer
    " can access to the instance.
    let blameobj.blamemeta = gita#command#blame#format(blameobj, winwidth(0))
    call gita#set_meta('winwidth', winwidth(0))
  endif
  call s:define_actions()
  augroup vim_gita_internal_blame_navi
    autocmd! * <buffer>
    autocmd CursorMoved <buffer> call s:on_CursorMoved()
    autocmd BufReadCmd  <buffer> nested call s:on_BufReadCmd()
  augroup END
  setlocal buftype=nowrite noswapfile nobuflisted
  setlocal nowrap nofoldenable foldcolumn=0 colorcolumn=0
  setlocal nonumber norelativenumber nolist
  setlocal nomodifiable
  setlocal scrollopt=ver
  setlocal filetype=gita-blame-navi
  call gita#command#blame#navi#redraw()
endfunction
function! gita#command#blame#navi#redraw() abort
  let blamemeta = gita#command#blame#_get_blamemeta_or_fail()
  call gita#util#buffer#edit_content(blamemeta.navi_content)
  call gita#command#blame#_set_pseudo_separators(blamemeta.separators)
endfunction

function! gita#command#blame#navi#define_highlights() abort
  highlight default link GitaHorizontal Comment
  highlight default link GitaSummary    Title
  highlight default link GitaMetaInfo   Comment
  highlight default link GitaAuthor     Identifier
  highlight default link GitaNotCommittedYet Constant
  highlight default link GitaTimeDelta  Comment
  highlight default link GitaRevision   String
  highlight default link GitaLineNr     LineNr
endfunction
function! gita#command#blame#navi#define_syntax() abort
  syntax match GitaSummary   /.*/ contains=GitaLineNr,GitaMetaInfo
  syntax match GitaLineNr    /^\s*[0-9]\+/
  syntax match GitaMetaInfo  /\%(\w\+ authored\|Not committed yet\) .*$/
        \ contains=GitaAuthor,GitaNotCommittedYet,GitaTimeDelta,GitaRevision
  syntax match GitaAuthor    /\w\+\ze authored/ contained
  syntax match GitaNotCommittedYet /Not committed yet/ contained
  syntax match GitaTimeDelta /authored \zs.*\ze\s\+[0-9a-fA-F]\{7}$/ contained
  syntax match GitaRevision  /[0-9a-fA-F]\{7}$/ contained
endfunction

call gita#util#define_variables('command#blame#navi', {
      \ 'default_opener': 'leftabove 50 vsplit',
      \ 'enable_default_mappings': 1,
      \})
