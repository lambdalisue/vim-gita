let s:V = gita#vital()
let s:Git = s:V.import('Git')
let s:GitTerm = s:V.import('Git.Term')

function! s:define_actions() abort
  call gita#command#ui#blame#define_actions()
  call gita#action#include([
        \ 'common', 'edit', 'show', 'diff',
        \], g:gita#command#ui#blame_navi#disable_default_mappings)

  if g:gita#command#ui#blame_navi#disable_default_mappings
    return
  endif
  execute printf(
        \ 'nmap <buffer> <Return> %s',
        \ g:gita#command#ui#blame_navi#primary_action_mapping
        \)
  execute printf(
        \ 'nmap <buffer> <S-Return> %s',
        \ g:gita#command#ui#blame_navi#secondary_action_mapping
        \)
endfunction

function! s:on_CursorMoved() abort
  try
    " Restrict cursor movement to mimic linenum columns
    let blamemeta = gita#meta#get_for('blame-navi', 'blamemeta')
    let linenum_width = blamemeta.linenum_width
    let column = col('.')
    if column <= linenum_width + 1
      call setpos('.', [0, line('.'), linenum_width + 2, 0])
    endif
  catch
    " fail silently
  endtry
endfunction

function! s:on_BufWinEnter() abort
  let options = gita#meta#get_for('blame-navi', 'options')
  let bufname = gita#command#ui#blame_view#bufname(options)
  let bufnum  = bufnr(bufname)
  if bufnum == -1 || bufwinnr(bufnum) == -1
    call gita#util#cascade#set('blame-view', options)
    call gita#util#buffer#open(bufname, {
          \ 'opener': printf(
          \   'rightbelow %d vsplit',
          \   winwidth(0) - g:gita#command#blame#navigator_width - 1,
          \ ),
          \ 'window': 'blame_view',
          \})
    set scrollbind
  endif
endfunction

function! s:on_BufReadCmd(options) abort
  let options = gita#option#cascade('^blame-navi$', a:options, {
        \ 'selection': [],
        \})
  let result = gita#command#blame#get_or_create(options)
  call gita#meta#set('content_type', 'blame-navi')
  call gita#meta#set('options', options)
  call gita#meta#set('previous', get(options, 'previous', []))
  call gita#meta#set('commit', result.commit)
  call gita#meta#set('filename', result.filename)
  call gita#meta#set('blamemeta', result.blamemeta)
  augroup vim_gita_internal_blame_navi
    autocmd! * <buffer>
    autocmd CursorMoved <buffer> call s:on_CursorMoved()
    autocmd BufWinEnter <buffer> nested call s:on_BufWinEnter()
  augroup END
  call s:define_actions()
  call gita#util#anchor#attach()
  call gita#util#observer#attach()
  setlocal buftype=nowrite noswapfile nobuflisted
  setlocal nowrap nofoldenable foldcolumn=0 colorcolumn=0
  setlocal nonumber norelativenumber nolist
  setlocal nomodifiable
  setlocal scrollopt=ver
  setlocal filetype=gita-blame-navi
  setlocal winfixwidth
  call gita#command#ui#blame_navi#redraw()
  call gita#command#ui#blame#select(result.blamemeta, options.selection)
endfunction


function! gita#command#ui#blame_navi#bufname(...) abort
  let options = extend({
        \ 'commit': '',
        \ 'filename': '',
        \}, get(a:000, 0, {}))
  let commit = gita#variable#get_valid_range(options.commit, {
        \ '_allow_empty': 1,
        \})
  let filename = gita#variable#get_valid_filename(options.filename)
  return gita#autocmd#bufname({
        \ 'content_type': 'blame-navi',
        \ 'extra_option': [],
        \ 'commitish': commit,
        \ 'path': filename,
        \})
endfunction

function! gita#command#ui#blame_navi#autocmd(name) abort
  let git = gita#core#get_or_fail()
  let bufname = expand('<afile>')
  let m = matchlist(bufname, '^gita://[^:\\/]\+:blame-navi[\\/]\(.*\)$')
  if empty(m)
    call gita#throw(printf(
          \ 'A bufname %s does not have required components',
          \ bufname,
          \))
  endif
  let [commit, unixpath] = s:GitTerm.split_treeish(m[1], { '_allow_range': 1 })
  let options = gita#util#cascade#get('blame-navi')
  let options.commit = commit
  let options.filename = empty(unixpath) ? '' : s:Git.get_absolute_path(git, unixpath)
  call call('s:on_' . a:name, [options])
endfunction

function! gita#command#ui#blame_navi#redraw() abort
  let blamemeta = gita#meta#get_for('blame-navi', 'blamemeta')
  call gita#util#buffer#edit_content(
        \ blamemeta.navi_content,
        \ gita#autocmd#parse_cmdarg(),
        \)
  call gita#command#ui#blame#set_pseudo_separators(blamemeta)
endfunction


call gita#util#define_variables('command#ui#blame_navi', {
      \ 'primary_action_mapping': '<Plug>(gita-blame-enter)',
      \ 'secondary_action_mapping': '<Plug>(gita-blame-back)',
      \ 'disable_default_mappings': 0,
      \})
