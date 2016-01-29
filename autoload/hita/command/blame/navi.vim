let s:V = hita#vital()
let s:Dict = s:V.import('Data.Dict')

function! s:get_entry(index) abort
  return {}
endfunction
function! s:define_actions() abort
  let action = hita#action#define(function('s:get_entry'))
  " Override 'redraw' action
  function! action.actions.redraw(candidates, ...) abort
    call hita#command#blame#navi#update()
  endfunction

  call hita#action#includes(
        \ g:hita#command#blame#navi#enable_default_mappings, [
        \   'close', 'redraw',
        \   'edit', 'show', 'diff', 'blame', 'browse',
        \])

  if g:hita#command#blame#navi#enable_default_mappings
    silent execute printf(
          \ 'map <buffer> <Return> %s',
          \ g:hita#command#blame#navi#default_action_mapping
          \)
  endif
endfunction

function! hita#command#blame#navi#bufname(...) abort
  let options = hita#option#init('blame-navi', get(a:000, 0, {}), {
        \ 'commit': '',
        \ 'filename': '',
        \})
  let hita = hita#get_or_fail()
  let commit = hita#variable#get_valid_range(options.commit, {
        \ '_allow_empty': 1,
        \})
  let filename = hita#variable#get_valid_filename(options.filename)
  return hita#autocmd#bufname(hita, {
        \ 'filebase': 0,
        \ 'content_type': 'blame-navi',
        \ 'extra_options': [],
        \ 'commitish': commit,
        \ 'path': filename,
        \})
endfunction
function! hita#command#blame#navi#call(...) abort
  let options = hita#option#init('blame-navi', get(a:000, 0, {}), {
        \ 'commit': '',
        \ 'filename': '',
        \})
  let bufname = hita#command#blame#bufname(options)
  let bufnum = bufnr(bufname)
  let content_type = hita#get_meta('content_type', '', bufnum)
  if bufnum == 0 || content_type !=# 'blame'
    call hita#throw('hita-blame-navi window requires a corresponding hita-blame buffer.')
  endif
  let commit = hita#get_meta('commit', '', bufnum)
  let filename = hita#get_meta('filename', '', bufnum)
  let content = hita#get_meta('content', [], bufnum)
  let blame = hita#get_meta('blame', {}, bufnum)
  if empty(blame)
    call hita#throw(printf('No blame information has found on %s', bufname))
  endif
  let result = {
        \ 'bufname': bufname,
        \ 'bufnum': bufnum,
        \ 'commit': commit,
        \ 'filename': filename,
        \ 'content': content,
        \ 'blame': blame,
        \}
  return result
endfunction
function! hita#command#blame#navi#open(...) abort
  let options = extend({
        \ 'opener': '',
        \}, get(a:000, 0, {}))
  let result = hita#command#blame#navi#call(options)
  let opener = empty(options.opener)
        \ ? g:hita#command#blame#default_opener
        \ : options.opener
  let bufname = hita#command#blame#navi#bufname(options)
  call hita#util#buffer#open(bufname, {
        \ 'opener': opener,
        \ 'group': 'blame_navigation_panel',
        \})
  call hita#set_meta('content_type', 'blame-navi')
  call hita#set_meta('options', s:Dict.omit(options, ['force']))
  call hita#set_meta('commit', result.commit)
  call hita#set_meta('filename', result.filename)
  call hita#set_meta('content', result.content)
  call hita#set_meta('blame', result.blame)
  call hita#set_meta('winwidth', winwidth(0))
  call s:define_actions()
  augroup vim_hita_status
    autocmd! * <buffer>
    autocmd BufReadCmd <buffer>
          \ call hita#command#blame#navi#update() |
          \ setlocal filetype=hita-blame-navi
    "autocmd VimResized <buffer> call s:on_VimResized()
    "autocmd WinEnter   <buffer> call s:on_WinEnter()
  augroup END
  setlocal buftype=nowrite noswapfile nobuflisted
  setlocal nowrap nofoldenable foldcolumn=0 colorcolumn=0
  setlocal nonumber nolist
  setlocal nomodifiable
  setlocal scrollopt=ver
  setlocal filetype=hita-blame-navi
  call hita#command#blame#navi#redraw()
endfunction
function! hita#command#blame#navi#update(...) abort
  if &filetype !=# 'hita-blame-navi'
    call hita#throw('update() requires to be called in a hita-blame-navi buffer')
  endif
  let options = get(a:000, 0, {})
  let result = hita#command#blame#navi#call(options)
  call hita#set_meta('content_type', 'blame-navi')
  call hita#set_meta('options', s:Dict.omit(options, ['force']))
  call hita#set_meta('commit', result.commit)
  call hita#set_meta('filename', result.filename)
  call hita#set_meta('content', result.content)
  call hita#set_meta('blame', result.blame)
  call hita#set_meta('winwidth', winwidth(0))
  call hita#command#blame#navi#redraw()
endfunction
function! hita#command#blame#navi#redraw() abort
  if &filetype !=# 'hita-blame-navi'
    call hita#throw('redraw() requires to be called in a hita-status buffer')
  endif
  let blame = hita#get_meta('blame')
  call hita#util#buffer#edit_content(blame.navi_content)
  call hita#command#blame#display_pseudo_separators(blame.separators)
endfunction

function! hita#command#blame#navi#define_highlights() abort
  call hita#command#blame#define_highlights()
  highlight default link HitaHorizontal Comment
  highlight default link HitaSummary    Title
  highlight default link HitaMetaInfo   Comment
  highlight default link HitaAuthor     Identifier
  highlight default link HitaTimeDelta  Comment
  highlight default link HitaRevision   String
  highlight default link HitaPrevious   Special
  highlight default link HitaLineNr     LineNr
endfunction
function! hita#command#blame#navi#define_syntax() abort
  syntax match HitaSummary   /\v.*/ contains=HitaLineNr,HitaMetaInfo,HitaPrevious
  syntax match HitaLineNr    /\v^\s*[0-9]+/
  syntax match HitaMetaInfo  /\v\w+ authored .*$/ contains=HitaAuthor,HitaTimeDelta,HitaRevision
  syntax match HitaAuthor    /\v\w+\ze authored/ contained
  syntax match HitaTimeDelta /\vauthored \zs.*\ze\s+[0-9a-fA-F]{7}$/ contained
  syntax match HitaRevision  /\v[0-9a-fA-F]{7}$/ contained
  syntax match HitaPrevious  /\vPrev: [0-9a-fA-F]{7}$/ contained
endfunction

call hita#util#define_variables('command#blame#navi', {
      \ 'default_action_mapping': '<Plug>(hita-show)',
      \ 'enable_default_mappings': 1,
      \})
