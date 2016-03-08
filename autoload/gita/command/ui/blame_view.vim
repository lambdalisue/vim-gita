let s:V = gita#vital()
let s:Prelude = s:V.import('Prelude')
let s:Git = s:V.import('Git')
let s:GitTerm = s:V.import('Git.Term')

function! s:define_actions() abort
  call gita#command#ui#blame#define_actions()
  call gita#action#include([
        \ 'common',
        \], g:gita#command#ui#blame_view#disable_default_mappings)

  if g:gita#command#ui#blame_view#disable_default_mappings
    return
  endif
  execute printf(
        \ 'nmap <buffer> <Return> %s',
        \ g:gita#command#ui#blame_view#primary_action_mapping
        \)
  execute printf(
        \ 'nmap <buffer> <S-Return> %s',
        \ g:gita#command#ui#blame_view#secondary_action_mapping
        \)
endfunction

function! s:on_BufWinEnter() abort
  let options = gita#meta#get_for('blame-view', 'options')
  let bufname = gita#command#ui#blame_navi#bufname(options)
  let bufnum  = bufnr(bufname)
  if bufnum == -1 || bufwinnr(bufnum) == -1
    call gita#util#cascade#set('blame-navi', options)
    call gita#util#buffer#open(bufname, {
          \ 'opener': printf(
          \   'leftabove %d vsplit',
          \   g:gita#command#blame#navigator_width,
          \ ),
          \ 'window': 'blame_navi',
          \})
    set scrollbind
  endif
endfunction

function! s:on_BufReadCmd(options) abort
  call gita#util#doautocmd('BufReadPre')
  let options = gita#option#cascade('^blame-view$', a:options, {
        \ 'selection': [],
        \})
  let result = gita#command#blame#get_or_create(options)
  call gita#meta#set('content_type', 'blame-view')
  call gita#meta#set('options', options)
  call gita#meta#set('previous', get(options, 'previous', []))
  call gita#meta#set('commit', result.commit)
  call gita#meta#set('filename', result.filename)
  call gita#meta#set('blamemeta', result.blamemeta)
  augroup vim_gita_internal_blame_view
    autocmd! * <buffer>
    autocmd BufWinEnter <buffer> nested call s:on_BufWinEnter()
  augroup END
  call s:define_actions()
  call gita#util#anchor#attach()
  call gita#util#observer#attach()
  setlocal nonumber norelativenumber nowrap nofoldenable foldcolumn=0
  setlocal buftype=nowrite noswapfile nobuflisted
  setlocal nomodifiable
  setlocal scrollopt=ver
  call gita#command#ui#blame_view#redraw()
  call gita#command#ui#blame#select(result.blamemeta, options.selection)
  call gita#util#doautocmd('BufReadPost')
endfunction


function! gita#command#ui#blame_view#bufname(...) abort
  let options = extend({
        \ 'commit': '',
        \ 'filename': '',
        \}, get(a:000, 0, {}))
  let commit = gita#variable#get_valid_range(options.commit, {
        \ '_allow_empty': 1,
        \})
  let filename = gita#variable#get_valid_filename(options.filename)
  return gita#autocmd#bufname({
        \ 'content_type': 'blame-view',
        \ 'extra_option': [],
        \ 'commitish': commit,
        \ 'path': filename,
        \})
endfunction

function! gita#command#ui#blame_view#autocmd(name) abort
  let git = gita#core#get_or_fail()
  let bufname = expand('<afile>')
  let m = matchlist(bufname, '^gita://[^:\\/]\+:blame-view[\\/]\(.*\)$')
  if empty(m)
    call gita#throw(printf(
          \ 'A bufname %s does not have required components',
          \ bufname,
          \))
  endif
  let [commit, unixpath] = s:GitTerm.split_treeish(m[1], { '_allow_range': 1 })
  let options = gita#util#cascade#get('blame-view')
  let options.commit = commit
  let options.filename = empty(unixpath) ? '' : s:Git.get_absolute_path(git, unixpath)
  call call('s:on_' . a:name, [options])
endfunction

function! gita#command#ui#blame_view#redraw() abort
  let blamemeta = gita#meta#get_for('blame-view', 'blamemeta')
  call gita#util#buffer#edit_content(
        \ blamemeta.view_content,
        \ gita#autocmd#parse_cmdarg(),
        \)
  call gita#command#ui#blame#set_pseudo_separators(blamemeta)
endfunction


call gita#util#define_variables('command#ui#blame_view', {
      \ 'primary_action_mapping': '<Plug>(gita-blame-enter)',
      \ 'secondary_action_mapping': '<Plug>(gita-blame-back)',
      \ 'disable_default_mappings': 0,
      \})
