let s:V = gita#vital()
let s:Dict = s:V.import('Data.Dict')

function! s:get_entry(index) abort
  return {}
endfunction
function! s:define_actions() abort
  let action = gita#action#define(function('s:get_entry'))
  " Override 'redraw' action
  function! action.actions.redraw(candidates, ...) abort
    call gita#command#blame#navi#update()
  endfunction

  call gita#action#includes(
        \ g:gita#command#blame#navi#enable_default_mappings, [
        \   'close', 'redraw',
        \   'edit', 'show', 'diff', 'blame', 'browse',
        \])

  if g:gita#command#blame#navi#enable_default_mappings
    execute printf(
          \ 'map <buffer> <Return> %s',
          \ g:gita#command#blame#navi#default_action_mapping
          \)
  endif
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
function! gita#command#blame#navi#call(...) abort
  let options = gita#option#init('blame-navi', get(a:000, 0, {}), {
        \ 'commit': '',
        \ 'filename': '',
        \})
  let bufname = gita#command#blame#bufname(options)
  let bufnum = bufnr(bufname)
  let content_type = gita#get_meta('content_type', '', bufnum)
  if bufnum == 0 || content_type !=# 'blame'
    call gita#throw('gita-blame-navi window requires a corresponding gita-blame buffer.')
  endif
  let commit = gita#get_meta('commit', '', bufnum)
  let filename = gita#get_meta('filename', '', bufnum)
  let content = gita#get_meta('content', [], bufnum)
  let blame = gita#get_meta('blame', {}, bufnum)
  if empty(blame)
    call gita#throw(printf('No blame information has found on %s', bufname))
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
function! gita#command#blame#navi#open(...) abort
  let options = extend({
        \ 'opener': '',
        \}, get(a:000, 0, {}))
  let result = gita#command#blame#navi#call(options)
  let opener = empty(options.opener)
        \ ? g:gita#command#blame#default_opener
        \ : options.opener
  let bufname = gita#command#blame#navi#bufname(options)
  call gita#util#buffer#open(bufname, {
        \ 'opener': opener,
        \ 'group': 'blame_navigation_panel',
        \})
  call gita#set_meta('content_type', 'blame-navi')
  call gita#set_meta('options', s:Dict.omit(options, ['force']))
  call gita#set_meta('commit', result.commit)
  call gita#set_meta('filename', result.filename)
  call gita#set_meta('content', result.content)
  call gita#set_meta('blame', result.blame)
  call gita#set_meta('winwidth', winwidth(0))
  call s:define_actions()
  augroup vim_gita_status
    autocmd! * <buffer>
    autocmd BufReadCmd <buffer>
          \ call gita#command#blame#navi#update() |
          \ setlocal filetype=gita-blame-navi
    "autocmd VimResized <buffer> call s:on_VimResized()
    "autocmd WinEnter   <buffer> call s:on_WinEnter()
  augroup END
  setlocal buftype=nowrite noswapfile nobuflisted
  setlocal nowrap nofoldenable foldcolumn=0 colorcolumn=0
  setlocal nonumber nolist
  setlocal nomodifiable
  setlocal scrollopt=ver
  setlocal filetype=gita-blame-navi
  call gita#command#blame#navi#redraw()
endfunction
function! gita#command#blame#navi#update(...) abort
  if &filetype !=# 'gita-blame-navi'
    call gita#throw('update() requires to be called in a gita-blame-navi buffer')
  endif
  let options = get(a:000, 0, {})
  let result = gita#command#blame#navi#call(options)
  call gita#set_meta('content_type', 'blame-navi')
  call gita#set_meta('options', s:Dict.omit(options, ['force']))
  call gita#set_meta('commit', result.commit)
  call gita#set_meta('filename', result.filename)
  call gita#set_meta('content', result.content)
  call gita#set_meta('blame', result.blame)
  call gita#set_meta('winwidth', winwidth(0))
  call gita#command#blame#navi#redraw()
endfunction
function! gita#command#blame#navi#redraw() abort
  if &filetype !=# 'gita-blame-navi'
    call gita#throw('redraw() requires to be called in a gita-status buffer')
  endif
  let blame = gita#get_meta('blame')
  call gita#util#buffer#edit_content(blame.navi_content)
  call gita#command#blame#display_pseudo_separators(blame.separators)
endfunction

function! gita#command#blame#navi#define_highlights() abort
  call gita#command#blame#define_highlights()
  highlight default link GitaHorizontal Comment
  highlight default link GitaSummary    Title
  highlight default link GitaMetaInfo   Comment
  highlight default link GitaAuthor     Identifier
  highlight default link GitaTimeDelta  Comment
  highlight default link GitaRevision   String
  highlight default link GitaPrevious   Special
  highlight default link GitaLineNr     LineNr
endfunction
function! gita#command#blame#navi#define_syntax() abort
  syntax match GitaSummary   /\v.*/ contains=GitaLineNr,GitaMetaInfo,GitaPrevious
  syntax match GitaLineNr    /\v^\s*[0-9]+/
  syntax match GitaMetaInfo  /\v\w+ authored .*$/ contains=GitaAuthor,GitaTimeDelta,GitaRevision
  syntax match GitaAuthor    /\v\w+\ze authored/ contained
  syntax match GitaTimeDelta /\vauthored \zs.*\ze\s+[0-9a-fA-F]{7}$/ contained
  syntax match GitaRevision  /\v[0-9a-fA-F]{7}$/ contained
  syntax match GitaPrevious  /\vPrev: [0-9a-fA-F]{7}$/ contained
endfunction

call gita#util#define_variables('command#blame#navi', {
      \ 'default_action_mapping': '<Plug>(gita-show)',
      \ 'enable_default_mappings': 1,
      \})
