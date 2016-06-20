let s:V = gita#vital()
let s:Path = s:V.import('System.Filepath')
let s:Guard = s:V.import('Vim.Guard')
let s:BufferAnchor = s:V.import('Vim.Buffer.Anchor')
let s:Git = s:V.import('Git')

function! s:parse_bufname(bufinfo) abort
  let m = matchlist(a:bufinfo.treeish, '^\([^:]*\)\%(:\(.*\)\)\?$')
  if empty(m)
    call gita#throw(printf(
          \ 'A treeish part of a buffer name "%s" does not follow "%s" pattern',
          \ a:bufinfo.bufname, '<rev>:<filename>',
          \))
  endif
  let git = gita#core#get_or_fail()
  let a:bufinfo.commit = m[1]
  let a:bufinfo.filename = s:Path.realpath(s:Git.abspath(git, m[2]))
  return a:bufinfo
endfunction

function! s:define_actions() abort
  call gita#action#attach(function('gita#content#blame#get_candidates'))
  call gita#action#include([
        \ 'common', 'blame', 'edit', 'show', 'diff',
        \], g:gita#content#blame_navi#disable_default_mappings)
  if g:gita#content#blame_navi#disable_default_mappings
    return
  endif
  execute printf(
        \ 'nmap <buffer> <Return> %s',
        \ g:gita#content#blame_navi#primary_action_mapping
        \)
endfunction

function! s:on_BufReadCmd(options) abort
  call gita#util#doautocmd('BufReadPre')
  let options = gita#util#option#cascade('^blame-navi$', a:options, {
        \ 'commit': '',
        \ 'filename': '',
        \})
  let blamemeta = gita#content#blame#retrieve(options)
  call gita#meta#set('content_type', 'blame-navi')
  call gita#meta#set('options', options)
  call gita#meta#set('commit', options.commit)
  call gita#meta#set('filename', options.filename)
  call gita#meta#set('blamemeta', blamemeta)
  augroup gita_internal_content_blame_navi
    autocmd! * <buffer>
    autocmd CursorMoved <buffer> call s:on_CursorMoved()
    autocmd BufEnter    <buffer> call s:on_BufEnter()
    autocmd BufWinEnter <buffer> nested call s:on_BufWinEnter()
    autocmd ColorScheme <buffer> call gita#content#blame#define_highlights()
  augroup END
  call s:define_actions()
  call s:BufferAnchor.attach()
  call gita#util#observer#attach()
  " the following options are required so overwrite everytime
  setlocal buftype=nowrite noswapfile nobuflisted
  setlocal nowrap nofoldenable foldcolumn=0 colorcolumn=0
  setlocal nonumber norelativenumber nolist
  setlocal nomodifiable
  setlocal scrollopt=ver
  setlocal filetype=gita-blame-navi
  setlocal winfixwidth
  call gita#content#blame_navi#redraw()
  call gita#util#doautocmd('BufReadPost')
endfunction

function! s:on_CursorMoved() abort
  try
    " Restrict cursor movement to mimic linenum columns
    let blamemeta = gita#meta#get_for('^blame-navi$', 'blamemeta')
    let linenum_width = blamemeta.linenum_width
    let [col, offset] = getpos('.')[2:]
    if col + offset <= linenum_width + 1
      call setpos('.', [0, line('.'), linenum_width + 2 - offset, offset])
    endif
  catch
    " fail silently
  endtry
endfunction

function! s:on_BufEnter() abort
  let options = gita#meta#get_for('^blame-navi$', 'options')
  let bufname = gita#content#blame_view#build_bufname(options)
  let bufnum  = bufnr(bufname)
  " Force the following requirements
  setlocal nowrap nofoldenable foldcolumn=0 colorcolumn=0
  setlocal nonumber norelativenumber nolist
  if bufnum > -1 || bufwinnr(bufnum) > -1
    " force to follow same linnum as the partner
    let winnum = winnr()
    let [col, offset] = getpos('.')[2:]
    noautocmd execute printf('keepjumps %dwincmd w', bufwinnr(bufnum))
    syncbind
    let linenum = line('.')
    noautocmd execute printf('keepjumps %dwincmd w', winnum)
    call setpos('.', [0, linenum, col, offset])
  endif
endfunction

function! s:on_BufWinEnter() abort
  let options = gita#meta#get_for('^blame-navi$', 'options')
  let bufname = gita#content#blame_view#build_bufname(options)
  let bufnum  = bufnr(bufname)
  if bufnum == -1 || bufwinnr(bufnum) == -1
    let opener = bufwinnr(bufnum) == -1
          \ ? printf(
          \   'rightbelow %d vsplit',
          \   winwidth(0) - g:gita#content#blame#navigator_width - 1
          \ )
          \ : 'edit'
    set scrollbind
    try
      let guard = s:Guard.store(['&eventignore'])
      set eventignore+=BufWinEnter
      call gita#util#cascade#set('blame-view', options)
      call gita#util#buffer#open(bufname, {
            \ 'opener': opener,
            \ 'window': 'blame_view',
            \ 'selection': [line('.')],
            \})
    finally
      call guard.restore()
    endtry
    set scrollbind
  endif
endfunction

function! gita#content#blame_navi#build_bufname(options) abort
  let git = gita#core#get_or_fail()
  let treeish = printf('%s:%s',
        \ get(a:options, 'commit', ''),
        \ s:Path.unixpath(s:Git.relpath(git, a:options.filename)),
        \)
  return gita#content#build_bufname('blame-navi', {
        \ 'treeish': treeish,
        \})
endfunction

function! gita#content#blame_navi#redraw() abort
  let blamemeta = gita#meta#get_for('^blame-navi$', 'blamemeta')
  call gita#util#buffer#edit_content(
        \ blamemeta.navi_content,
        \ gita#util#buffer#parse_cmdarg(),
        \)
  call gita#content#blame#set_pseudo_separators(blamemeta)
endfunction

function! gita#content#blame_navi#autocmd(name, bufinfo) abort
  let bufinfo = s:parse_bufname(a:bufinfo)
  let options = extend(gita#util#cascade#get('blame-navi'), {
        \ 'commit': bufinfo.commit,
        \ 'filename': bufinfo.filename,
        \})
  for attribute in a:bufinfo.extra_options
    let options[attribute] = 1
  endfor
  call call('s:on_' . a:name, [options])
endfunction

call gita#define_variables('content#blame_navi', {
      \ 'disable_default_mappings': 0,
      \ 'primary_action_mapping': '<Plug>(gita-blame-enter)',
      \})
