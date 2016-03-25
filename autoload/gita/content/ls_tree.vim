let s:V = gita#vital()
let s:Prelude = s:V.import('Prelude')
let s:Dict = s:V.import('Data.Dict')
let s:Git = s:V.import('Git')
let s:GitParser = s:V.import('Git.Parser')

function! s:build_bufname(options) abort
  let options = extend({
        \ 'commit': 'HEAD',
        \}, a:options)
  return gita#content#build_bufname('ls-tree', {
        \ 'nofile': 1,
        \ 'extra_options': [
        \   options.commit,
        \ ],
        \})
endfunction

function! s:execute_command(options) abort
  let args = [
        \ 'ls-tree',
        \ '--full-name',
        \ '--full-tree',
        \ '--name-only',
        \ '-r',
        \ a:options.commit
        \]
  let args += ['--'] + a:options.filenames
  let git = gita#core#get_or_fail()
  return gita#process#execute(git, args, { 'quiet': 1 })
endfunction

function! s:define_actions() abort
  call gita#action#attach(function('s:get_candidate'))
  call gita#action#include([
        \ 'common', 'edit', 'show', 'diff', 'browse', 'blame',
        \], g:gita#content#ls_tree#disable_default_mappings)

  if g:gita#content#ls_tree#disable_default_mappings
    return
  endif
  execute printf(
        \ 'nmap <buffer> <Return> %s',
        \ g:gita#content#ls_tree#primary_action_mapping
        \)
endfunction

function! s:get_candidate(index) abort
  let record = getline(a:index + 1)
  let candidates = gita#meta#get_for('^ls-tree$', 'candidates', [])
  return gita#action#find_candidate(candidates, record, 'path')
endfunction

function! s:extend_filename(filename) abort
  return { 'path': a:filename }
endfunction

function! s:get_prologue(git) abort
  let commit = gita#meta#get_for('^ls-tree$', 'commit', '')
  let candidates = gita#meta#get_for('^ls-tree$', 'candidates', [])
  let ncandidates = len(candidates)
  return printf(
        \ 'Files in <%s> (%d file%s) %s',
        \ empty(commit) ? 'INDEX' : commit,
        \ ncandidates,
        \ ncandidates == 1 ? '' : 's',
        \ '| Press ? or <Tab> to show help or do action',
        \)
endfunction

function! s:on_BufReadCmd(options) abort
  call gita#util#doautocmd('BufReadPre')
  let options = gita#option#cascade('^ls-tree$', a:options, {
        \ 'commit': 'HEAD',
        \ 'filenames': [],
        \})
  let content = s:execute_command(options)
  let candidates = map(content, 's:extend_filename(v:val)')
  call gita#meta#set('content_type', 'ls-tree')
  call gita#meta#set('options', options)
  call gita#meta#set('commit', options.commit)
  call gita#meta#set('candidates', candidates)
  call s:define_actions()
  call gita#util#anchor#attach()
  call gita#util#observer#attach()
  " the following options are required so overwrite everytime
  setlocal filetype=gita-ls-tree
  setlocal buftype=nofile nobuflisted
  setlocal nomodifiable
  call gita#content#ls_tree#redraw()
  call gita#util#doautocmd('BufReadPost')
endfunction

function! gita#content#ls_tree#open(options) abort
  let options = extend({
        \ 'opener': '',
        \ 'window': 'manipulation_window',
        \}, a:options)
  let bufname = s:build_bufname(options)
  let opener = empty(options.opener)
        \ ? g:gita#content#ls_tree#default_opener
        \ : options.opener
  call gita#util#cascade#set('ls-tree', s:Dict.pick(options, [
        \ 'commit',
        \ 'filenames',
        \]))
  call gita#util#buffer#open(bufname, {
        \ 'opener': opener,
        \ 'window': options.window,
        \})
endfunction

function! gita#content#ls_tree#redraw() abort
  let git = gita#core#get_or_fail()
  let prologue = [s:get_prologue(git)]
  let contents = map(
        \ copy(gita#meta#get_for('^ls-tree$', 'candidates', [])),
        \ 'v:val.path',
        \)
  call gita#util#buffer#edit_content(
        \ extend(prologue, contents),
        \ gita#util#buffer#parse_cmdarg(),
        \)
endfunction

function! gita#content#ls_tree#autocmd(name, bufinfo) abort
  let options = gita#util#cascade#get('ls-tree')
  for attribute in a:bufinfo.extra_options
    let options[attribute] = 1
  endfor
  call call('s:on_' . a:name, [options])
endfunction

call gita#define_variables('content#ls_tree', {
      \ 'default_opener': 'botright 10 split',
      \ 'primary_action_mapping': '<Plug>(gita-edit)',
      \ 'disable_default_mappings': 0,
      \})